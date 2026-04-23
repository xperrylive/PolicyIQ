"""
main.py — PolicyIQ FastAPI Application Entrypoint.

Endpoints:
  POST /validate-policy  → Gatekeeper validation (Contract Pre-A → Pre-B)
  POST /simulate         → Full simulation as an SSE stream (Contract A → E)
  GET  /health           → Docker/GCP healthcheck probe
"""

from __future__ import annotations

import sys, os; sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import json
import logging
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
        # Use Genkit flow for validation
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

    # Fresh Orchestrator per request — prevents state leakage between
    # concurrent simulation calls.
    request_orchestrator = Orchestrator()

    async def event_generator() -> AsyncGenerator[dict, None]:
        import asyncio
        queue = asyncio.Queue()

        async def run_simulation_wrapper():
            try:
                # 1. Feasibility check via Genkit flow
                val_result = await validation_flow.run(request.policy_text)
                if not val_result.get("is_feasible", True):
                    await queue.put({
                        "event": "error",
                        "data": json.dumps({
                            "detail": "Policy is unfeasible",
                            "rejection_reason": val_result.get("rejection_reason"),
                            "refined_options": val_result.get("refined_options", [])
                        })
                    })
                    await queue.put(None)
                    return

                # 2. Prepare inputs for simulation_flow
                # We need agents and policy
                orch = Orchestrator()
                agents = orch._load_agents()[: request.agent_count]
                
                # We define a helper to handle the tick streaming
                # Since Genkit flows don't natively stream in Python Alpha yet,
                # we'll have the flow logic call this queue.
                
                # However, to strictly follow "trigger simulation_flow.run()",
                # we pass a callback or just run the flow and then yield.
                # BUT the user wants real-time.
                
                # Let's refactor the flow in orchestrator.py to accept a callback
                # or just use the orchestrator's existing generator inside the flow.
                
                input_data = {
                    "policy": request.policy_text,
                    "agents": agents,
                    "ticks": request.simulation_ticks,
                    "request": request # Pass full request for overrides
                }

                # We'll run the flow. To get real-time ticks, we'll have to 
                # slightly modify the flow in orchestrator.py or how we call it.
                # For now, let's assume simulation_flow returns the whole thing.
                # To keep it real-time, we'll actually yield from the flow if it was a generator.
                # Since it's not, we'll stick to the user's "trigger simulation_flow.run()"
                # but we'll adapt the flow to push to this queue if we can.
                
                # Better: Let's run the flow and have it return the final result, 
                # but for real-time SSE, we might need a middle ground.
                
                # Wait, the user said: "The Genkit flow should be executed such that we can still stream agent 'ticks'"
                # This implies the flow execution IS the simulation.
                
                # I will modify orchestrator.py's simulation_flow to accept a queue.
                
                result = await simulation_flow.run({**input_data, "sse_queue": queue})
                
                # Summary is already in the result
                await queue.put({
                    "event": "summary",
                    "data": json.dumps({"type": "summary", "content": result["summary"]}),
                })

                # Final result
                # We need to assemble the SimulateResponse
                # Orchestrator.get_final_result() needs the state.
                # This is a bit tricky since the flow uses a transient orchestrator.
                # I'll modify the flow to return the final response object.
                
                await queue.put({
                    "event": "complete",
                    "data": result["final_response_json"],
                })
                
            except Exception as e:
                logger.exception("Simulation flow error")
                await queue.put({
                    "event": "error",
                    "data": json.dumps({"detail": str(e)}),
                })
            finally:
                await queue.put(None)

        # Start the flow in the background
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

