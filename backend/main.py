"""
main.py — PolicyIQ FastAPI Application Entrypoint.

Endpoints:
  POST /validate-policy              → Gatekeeper validation (Contract Pre-A → Pre-B)
  POST /simulate                     → Full simulation as an SSE stream (Contract A → E)
  GET  /export-report/{simulation_id} → Pitch-ready text report for a completed simulation
  GET  /health                       → Docker/GCP healthcheck probe
"""

from __future__ import annotations

import sys, os; sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import json
import logging
import uuid
from pathlib import Path
from typing import AsyncGenerator


from dotenv import load_dotenv

# Load .env from the project root (one level up from backend/).
# Uses override=False so Docker env_file values always take precedence.
# If .env doesn't exist (Docker), this is silently a no-op.
_env_path = Path(__file__).resolve().parent.parent / ".env"
load_dotenv(_env_path, override=False)


from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sse_starlette.sse import EventSourceResponse

from backend.schemas import (
    ValidatePolicyRequest,
    ValidatePolicyResponse,
    SimulateRequest,
    SimulateResponse,
    EnvironmentBlueprint,
)
from backend.ai_engine.orchestrator import (
    Orchestrator,
    validation_flow,
    simulation_flow,
    ai
)

# ─── Logging ─────────────────────────────────────────────────────────────────
logging.basicConfig(level=logging.INFO, format="%(levelname)s │ %(name)s │ %(message)s")
logger = logging.getLogger("policyiq.main")

# ─── App ─────────────────────────────────────────────────────────────────────
app = FastAPI(
    title="PolicyIQ API",
    description=(
        "Multi-agent AI simulation engine for stress-testing Malaysian government policies. "
        "Translates raw policy text into an 8-Knob state matrix and simulates 50 Digital "
        "Malaysians across configurable time steps."
    ),
    version="0.1.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# ─── CORS ─────────────────────────────────────────────────────────────────────
# Allow the Flutter web app (and local dev tooling) to call the API.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # Tighten for production; fine for hackathon
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── Orchestrator ────────────────────────────────────────────────────────────
# NOTE: validate_policy is stateless so a shared instance is safe.
# run_simulation holds per-request state (_tick_results, _agents, etc.)
# so /simulate creates a FRESH Orchestrator per call to prevent data
# corruption under concurrent requests.
_shared_orchestrator = Orchestrator()

# ─── In-memory simulation store ──────────────────────────────────────────────
# Maps simulation_id → completed SimulateResponse dict (last 20 runs kept).
_simulation_store: dict[str, dict] = {}


# ─── Health ──────────────────────────────────────────────────────────────────
@app.get("/health", tags=["ops"], summary="Liveness probe")
async def health() -> dict:
    """Simple liveness probe used by Docker healthcheck and Cloud Run."""
    return {"status": "ok", "service": "policyiq-backend"}


# ─── Contract Pre-A → Pre-B ──────────────────────────────────────────────────
@app.post(
    "/validate-policy",
    response_model=ValidatePolicyResponse,
    tags=["gatekeeper"],
    summary="Validate raw policy text before simulation",
)
async def validate_policy(request: ValidatePolicyRequest) -> ValidatePolicyResponse:
    """
    **The Gatekeeper.**

    Runs a fast Gemini 1.5 Flash check on the submitted policy text.
    Returns a validation verdict (Contract Pre-B).

    - If `is_feasible` is `false`, the response includes a `rejection_reason` and
      up to 3 specific `refined_options` the user can adopt instead.
    - If `is_feasible` is `true`, the frontend should proceed to `POST /simulate`.
    """
    logger.info("Gatekeeper received policy: %.80s…", request.raw_policy_text)
    try:
        # Use Genkit flow for validation — returns full ValidatePolicyResponse dict
        # including the EnvironmentBlueprint when is_feasible=True
        result_dict = await validation_flow.run(request.raw_policy_text)
        return ValidatePolicyResponse(**result_dict)
    except Exception as exc:
        logger.exception("Gatekeeper error")
        raise HTTPException(status_code=500, detail=str(exc)) from exc


# ─── Contract A → E (SSE) ────────────────────────────────────────────────────
@app.post(
    "/simulate",
    tags=["simulation"],
    summary="Run the full multi-agent policy simulation (SSE stream)",
)
async def simulate(request: SimulateRequest) -> EventSourceResponse:
    """
    **The Simulation Engine.**

    Accepts a validated policy and optional Knob overrides (Contract A).
    Returns a Server-Sent Events stream where each event is either:

    - **`tick`** — JSON payload for a completed simulation tick (partial Contract E).
    - **`complete`** — Final `SimulateResponse` payload (full Contract E).
    - **`error`** — Error details if the simulation fails mid-run.

    Flutter client should listen with an SSE-capable HTTP client.
    """
    logger.info(
        "Simulation request │ ticks=%d agents=%d",
        request.simulation_ticks,
        request.agent_count,
    )

    # Fresh Orchestrator per request is now handled inside simulation_flow.
    # No shared state needed here.
    simulation_id = str(uuid.uuid4())

    async def event_generator() -> AsyncGenerator[dict, None]:
        import asyncio
        queue: asyncio.Queue = asyncio.Queue()

        async def run_simulation_wrapper() -> None:
            try:
                input_data = {
                    "policy":    request.policy_text,
                    "request":   request,
                    "sse_queue": queue,
                }
                result = await simulation_flow.run(input_data)

                if "error" in result:
                    # simulation_flow already pushed an error event; just close.
                    return

                # Store completed result for /export-report
                _simulation_store[simulation_id] = {
                    "policy_text":     request.policy_text,
                    "final_response":  result.get("final_response_json", "{}"),
                    "summary":         result.get("summary", ""),
                }
                # Evict oldest entries beyond 20
                if len(_simulation_store) > 20:
                    oldest = next(iter(_simulation_store))
                    del _simulation_store[oldest]

                # Push the simulation_id so the client can reference it
                await queue.put({
                    "event": "simulation_id",
                    "data":  json.dumps({"simulation_id": simulation_id}),
                })

                # Push the Chief Economist summary as a dedicated event.
                await queue.put({
                    "event": "summary",
                    "data":  json.dumps({"type": "summary", "content": result.get("summary", "")}),
                })

                # Push the full Contract E payload as the terminal "complete" event.
                await queue.put({
                    "event": "complete",
                    "data":  result.get("final_response_json", "{}"),
                })

            except Exception as e:
                logger.exception("Simulation flow error")
                await queue.put({
                    "event": "error",
                    "data":  json.dumps({"detail": str(e)}),
                })
            finally:
                await queue.put(None)  # sentinel — signals the generator to stop

        asyncio.create_task(run_simulation_wrapper())

        while True:
            item = await queue.get()
            if item is None:
                break
            yield item

    return EventSourceResponse(event_generator())


if __name__ == "__main__":
    import uvicorn
    # Using string import to avoid issues with reload and full module paths
    uvicorn.run("backend.main:app", host="0.0.0.0", port=8000, reload=True)


# ─── GET /export-report/{simulation_id} ──────────────────────────────────────
@app.get(
    "/export-report/{simulation_id}",
    tags=["simulation"],
    summary="Generate a pitch-ready text report for a completed simulation",
)
async def export_report(simulation_id: str) -> dict:
    """
    **The Pitch-Ready Report.**

    Returns a structured text summary of a completed simulation including:
    - Environment Blueprint (policy summary + knob state)
    - Final Reward Stability Score
    - Most critical agent monologues ('Voice of the People')
    """
    stored = _simulation_store.get(simulation_id)
    if not stored:
        raise HTTPException(
            status_code=404,
            detail=f"Simulation '{simulation_id}' not found. Run a simulation first.",
        )

    policy_text = stored.get("policy_text", "")
    summary_text = stored.get("summary", "")

    try:
        final_data = json.loads(stored.get("final_response", "{}"))
    except json.JSONDecodeError:
        final_data = {}

    # ── Extract key data ──────────────────────────────────────────────────────
    metadata   = final_data.get("simulation_metadata", {})
    macro      = final_data.get("macro_summary", {})
    timeline   = final_data.get("timeline", [])
    anomalies  = final_data.get("anomalies", [])

    # Final stability score = last tick's reward_stability_score
    final_stability = 0.0
    if timeline:
        final_stability = timeline[-1].get("reward_stability_score", 0.0)

    # Voice of the People: top 5 most critical monologues (lowest sentiment)
    all_monologues: list[dict] = []
    for tick in timeline:
        for action in tick.get("agent_actions", []):
            monologue = action.get("internal_monologue", "").strip()
            if monologue:
                all_monologues.append({
                    "tick":              tick.get("tick_id", 0),
                    "agent_id":          action.get("agent_id", ""),
                    "sentiment":         action.get("sentiment_score", 0.0),
                    "monologue":         monologue,
                    "is_breaking_point": action.get("is_breaking_point", False),
                })

    # Sort by sentiment ascending (most distressed first), take top 5
    critical_voices = sorted(all_monologues, key=lambda x: x["sentiment"])[:5]

    # ── Build report text ─────────────────────────────────────────────────────
    stability_label = (
        "STABLE" if final_stability >= 70
        else "MODERATE" if final_stability >= 40
        else "POLICY FAILURE / SOCIAL UNREST"
    )

    lines = [
        "=" * 60,
        "  POLICYIQ — SIMULATION REPORT",
        f"  Simulation ID: {simulation_id}",
        "=" * 60,
        "",
        "── ENVIRONMENT BLUEPRINT ──────────────────────────────────",
        f"Policy: {policy_text[:200]}{'...' if len(policy_text) > 200 else ''}",
        f"Summary: {metadata.get('policy', summary_text)[:300]}",
        f"Total Ticks: {metadata.get('total_ticks', len(timeline))}",
        "",
        "── FINAL REWARD STABILITY SCORE ───────────────────────────",
        f"Score: {final_stability:.1f} / 100  [{stability_label}]",
        f"Overall Sentiment Shift: {macro.get('overall_sentiment_shift', 0.0):+.4f}",
        f"Inequality Delta: {macro.get('inequality_delta', 0.0):+.4f}",
        f"Breaking Points (Anomalies): {len(anomalies)}",
        "",
        "── VOICE OF THE PEOPLE (Most Critical Monologues) ─────────",
    ]

    if critical_voices:
        for i, v in enumerate(critical_voices, 1):
            bp_tag = " ⚠ BREAKING POINT" if v["is_breaking_point"] else ""
            lines += [
                "",
                f"[{i}] Tick {v['tick']} | Agent {v['agent_id']} | "
                f"Sentiment {v['sentiment']:+.3f}{bp_tag}",
                f"    \"{v['monologue'][:300]}\"",
            ]
    else:
        lines.append("  No agent monologues recorded.")

    lines += [
        "",
        "── AI POLICY RECOMMENDATION ───────────────────────────────",
        final_data.get("ai_policy_recommendation", summary_text or "N/A"),
        "",
        "=" * 60,
    ]

    report = "\n".join(lines)
    logger.info(
        "Export report generated │ simulation_id=%s │ stability=%.1f",
        simulation_id, final_stability,
    )

    return {
        "simulation_id":   simulation_id,
        "final_stability": final_stability,
        "stability_label": stability_label,
        "report":          report,
    }
