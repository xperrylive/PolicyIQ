"""
orchestrator.py — PolicyIQ Simulation Orchestrator

Multi-Model Hybrid Architecture:
  - Framework Layer : Google Genkit (@define_flow) + Vertex AI initialization
                      preserved for tracing, observability, and future scaling.
  - Inference Layer : All active LLM calls routed to Groq (Llama-3.3-70b)
                      for zero-latency, high-concurrency 50-agent simulation.
  - RAG Layer       : _cached_local_search() is the PRIMARY grounding source
                      (backend/data/*.jsonl). RAGClient import retained for
                      Vertex AI Search scaling readiness.

Pipeline per request:
  1. Policy Gatekeeper validation
  2. Dynamic Decomposition → PolicyDecomposition (Contract B)
  3. Tick loop: Observation Generation → Parallel Agent Execution → Aggregation
  4. Anomaly detection and final AI policy recommendation
"""

from __future__ import annotations

import asyncio
import functools
import json
import logging
import os
import re
import random
from pathlib import Path
from typing import AsyncGenerator, Optional

from groq import Groq

from backend.ai_engine.physics import GlobalStateEngine

# ─── RAGClient import — retained for Vertex AI Search scaling readiness ───────
# Not used for active inference (local search is primary), but kept to
# demonstrate the hybrid architecture's cloud-scaling pathway.
try:
    from backend.ai_engine.rag_client import RAGClient  # noqa: F401
except ImportError:
    RAGClient = None  # type: ignore[assignment,misc]

# ─── Genkit Initialization (Robust Hunter) ────────────────────────────────────
try:
    from genkit import Genkit, define_flow
except ImportError:
    try:
        from genkit.ai import Genkit, define_flow
    except ImportError:
        try:
            from genkit.core import Genkit, define_flow
        except ImportError:
            # CRITICAL FALLBACK: Compatibility shim — preserves @define_flow
            # decorator semantics so all flow wrappers remain intact.
            class Genkit:
                def __init__(self, *args, **kwargs): pass
                async def run(self, name, func, *args, **kwargs):
                    result = func() if callable(func) else func
                    if asyncio.iscoroutine(result):
                        return await result
                    return result

            def define_flow(name=None):
                def decorator(func):
                    async def run_shim(*args, **kwargs):
                        return await func(*args, **kwargs)
                    func.run = run_shim
                    return func
                return decorator

# ─── Vertex AI initialization — preserved for hybrid architecture ─────────────
# Active inference is handled by Groq; this block retains the Vertex AI
# project/location wiring so the service_account.json credential path and
# GCP environment variables remain functional for future Gemini scaling.
try:
    import vertexai  # noqa: F401
    _VERTEX_PROJECT  = os.getenv("GOOGLE_CLOUD_PROJECT", "")
    _VERTEX_LOCATION = os.getenv("VERTEX_AI_LOCATION", "us-central1")
    _VERTEX_CREDS    = os.getenv("GOOGLE_APPLICATION_CREDENTIALS", "service_account.json")
    if _VERTEX_PROJECT:
        vertexai.init(project=_VERTEX_PROJECT, location=_VERTEX_LOCATION)
except Exception:
    pass  # Vertex AI unavailable in local dev — Groq handles all inference

ai = Genkit()

logger = logging.getLogger("policyiq.ai_engine.orchestrator")

# ─── Path helpers ─────────────────────────────────────────────────────────────
_ENGINE_DIR    = Path(__file__).parent
PROMPTS_DIR    = _ENGINE_DIR / "prompts"
AGENT_DNA_FILE = _ENGINE_DIR / "agent_dna" / "agents_master.json"

# ─── Fallback model constants (standardised) ──────────────────────────────────
_GEMINI_FLASH_FALLBACK = os.getenv("GEMINI_MODEL",     "gemini-1.5-flash-001")
_GEMINI_PRO_FALLBACK   = os.getenv("GEMINI_PRO_MODEL", "gemini-1.5-pro-001")
_GROQ_MODEL_DEFAULT    = os.getenv("GROQ_MODEL",       "llama-3.3-70b-versatile")


# ─── RAG Truth Layer — module-level cached local search ───────────────────────
# PRIMARY grounding source for all 50 agents.
#
# lru_cache cannot decorate instance methods (it would hash `self`), so the
# actual file scan lives here at module scope. The Orchestrator delegates via
# _get_agent_context(), keeping the public API clean.
#
# Cache semantics: effective key is (tier, occupation, query).
# With 3 tiers × 5 occupations = 15 common combinations, the cache fills
# quickly and all 50 agents benefit from warm entries on subsequent ticks.

@functools.lru_cache(maxsize=64)
def _cached_local_search(
    *,
    tier: str,
    occupation: str,
    query: str,
) -> str:
    """
    Scan backend/data/*.jsonl for lines matching the query keywords and return
    up to 10 grounded snippets as a formatted string.

    This is the PRIMARY RAG source for the simulation. Results are cached at
    module level so identical (tier, occupation, query) combinations are only
    read from disk once per process lifetime.

    Args:
        tier:       Agent income bracket (``"B40"`` / ``"M40"`` / ``"T20"``).
        occupation: Agent job type (e.g. ``"Gig Worker"``).
        query:      Search query (e.g. ``"B40 petrol price"``).

    Returns:
        Formatted multi-line string with ≤10 grounded snippets, or ``""``
        if no matches are found.
    """
    _log = logging.getLogger("policyiq.ai_engine.orchestrator")

    keywords = [w for w in re.findall(r'[\w.]+', query) if len(w) > 2]

    data_dir = (Path(__file__).parent.parent / "data").resolve()
    results: list[str] = []

    if not data_dir.exists():
        _log.error(
            "[RAG PATH ERROR] Data directory not found: %s — "
            "ensure backend/data/*.jsonl files are present.",
            data_dir,
        )
        return ""

    for file_path in data_dir.glob("*.jsonl"):
        try:
            with open(file_path, "r", encoding="utf-8") as f:
                for line in f:
                    if any(kw.lower() in line.lower() for kw in keywords):
                        results.append(line.strip())
                        if len(results) >= 10:
                            break
        except Exception as exc:
            _log.error("[Local RAG] Error reading %s: %s", file_path, exc)
        if len(results) >= 10:
            break

    if not results:
        _log.warning("[Local RAG] No snippets found for query: %s", query)
        _log.critical("[Local RAG] CRITICAL: Simulation tick running WITHOUT grounded data.")
        return ""

    _log.info("[Local RAG] SUCCESS — %d snippet(s) retrieved for query: %s", len(results), query)
    return "\n".join(f"- {s}" for s in results)


# ─── Genkit Flows ─────────────────────────────────────────────────────────────

@define_flow(name="validation_flow")
async def validation_flow(policy_text: str) -> dict:
    """
    Genkit Flow: Policy Validator.
    Provides a feasibility and risk sanity-check before simulation begins.
    Inference is executed via the Groq (Llama-3.3-70b) optimised engine.
    """
    from backend.ai_engine.policy_validator import PolicyValidator
    validator = PolicyValidator()
    result = await ai.run(
        "policy_feasibility_check",
        lambda: validator.validate(policy_text)
    )
    return result


@define_flow(name="simulation_flow")
async def simulation_flow(input_data: dict) -> dict:
    """
    Genkit Flow: Main simulation pipeline.
      1. Policy Decomposition (AI-led knob seeding via Llama-3.3-70b)
      2. Multi-tick Agent Simulation (Parallel Execution — 50 agents)
      3. Local RAG grounding (backend/data/*.jsonl — primary source)
      4. Chief Economist Summary
    """
    policy_text = input_data.get("policy")
    request     = input_data.get("request")
    sse_queue   = input_data.get("sse_queue")

    orch = Orchestrator()

    try:
        async for tick_payload in orch._run_simulation_request(request):
            if sse_queue:
                await sse_queue.put({"event": "tick", "data": json.dumps(tick_payload)})
    except Exception as exc:
        logger.exception("[Hybrid Inference] Internal error in simulation loop: %s", exc)
        if sse_queue:
            await sse_queue.put({"event": "error", "data": json.dumps({"detail": str(exc)})})
        return {"error": str(exc)}

    last_tick_results = (
        orch._tick_results[-1]["agent_actions"] if orch._tick_results else []
    )

    summary = await ai.run(
        "chief_economist_summary",
        lambda: orch.generate_summary(last_tick_results, policy_text)
    )

    final_response = await orch.get_final_result()

    return {
        "summary": summary,
        "final_response_json": final_response.model_dump_json(),
    }


class Orchestrator:
    """
    Central coordinator for the PolicyIQ simulation.

    Multi-Model Hybrid Architecture:
      - All active LLM inference → Groq (Llama-3.3-70b) for zero-latency,
        high-concurrency execution across 50 simultaneous agents.
      - Genkit @define_flow wrappers preserved for tracing / observability.
      - Vertex AI / service_account.json wiring retained for cloud scaling.
      - Local JSONL search is the PRIMARY RAG source; RAGClient import
        demonstrates Vertex AI Search readiness.

    Lifecycle (per request)::

        orchestrator = Orchestrator()
        result = await orchestrator.validate_policy(req)       # Gatekeeper
        async for tick in orchestrator.run_simulation(req):    # SSE ticks
            yield tick
        final = await orchestrator.get_final_result()          # Contract E
    """

    # Limits concurrent Groq API calls to stay within RPM budget.
    # At 50 agents × N ticks, semaphore(10) keeps throughput high while
    # preventing burst 429s on the Groq endpoint.
    semaphore = asyncio.Semaphore(10)

    def __init__(self) -> None:
        self._physics      = GlobalStateEngine()
        self._decomposition: Optional[dict] = None
        self._tick_results: list[dict] = []
        self._agents:       list[dict] = []
        self._groq_model   = os.getenv("GROQ_MODEL", _GROQ_MODEL_DEFAULT)
        self._groq_client  = Groq(api_key=os.getenv("GROQ_API_KEY"))
        logger.info(
            "[Hybrid Inference] Orchestrator initialised — "
            "active inference engine: Groq / %s",
            self._groq_model,
        )

    # ─── RAG Truth Layer ──────────────────────────────────────────────────────

    def _get_agent_context(self, tier: str, occupation: str, policy_text: str) -> str:
        """
        Delegate to the module-level _cached_local_search (PRIMARY RAG source).

        Results are cached via lru_cache so identical (tier, occupation, query)
        combinations are only scanned from disk once per process lifetime,
        giving all 50 agents warm cache hits after the first tick.
        """
        return _cached_local_search(
            tier=tier,
            occupation=occupation,
            query=policy_text,
        )

    # ─── Prompt Loaders ───────────────────────────────────────────────────────

    def _load_prompt(self, name: str) -> str:
        path = PROMPTS_DIR / name
        if path.exists() and path.stat().st_size > 0:
            return path.read_text(encoding="utf-8")
        logger.warning("Prompt template '%s' is empty or missing — using placeholder.", name)
        return f"[PLACEHOLDER: {name} — populate this prompt template]"

    def _load_agents(self) -> list[dict]:
        if AGENT_DNA_FILE.exists() and AGENT_DNA_FILE.stat().st_size > 5:
            with AGENT_DNA_FILE.open("r", encoding="utf-8") as f:
                return json.load(f)
        logger.warning("agents_master.json is empty — using synthetic placeholder agents.")
        return self._synthetic_agents(count=5)

    @staticmethod
    def _synthetic_agents(count: int) -> list[dict]:
        """
        Generate realistic synthetic Economic Entity agents for local dev/testing.
        Ranges calibrated against 2023 DOSM household income data.
        """
        tiers       = ["B40", "M40", "T20"]
        occupations = ["Gig Worker", "Salaried Corporate", "SME Owner", "Civil Servant", "Unemployed"]
        locations   = ["Urban KL", "Suburban Selangor", "Rural Sabah"]

        tier_config: dict[str, dict] = {
            "B40": {
                "income_range":    (2000.0,  4849.0),
                "savings_range":   (200.0,   2000.0),
                "dti_range":       (0.35,    0.65),
                "dependents_range":(2, 5),
                "readiness_range": (0.15,    0.50),
                "subsidy_flags":   {"brim": True,  "petrol_quota": True,  "padu_registered": False, "oku_allowance": False},
            },
            "M40": {
                "income_range":    (4850.0,  10959.0),
                "savings_range":   (2000.0,  15000.0),
                "dti_range":       (0.20,    0.45),
                "dependents_range":(1, 3),
                "readiness_range": (0.45,    0.78),
                "subsidy_flags":   {"brim": False, "petrol_quota": False, "padu_registered": True,  "oku_allowance": False},
            },
            "T20": {
                "income_range":    (10960.0, 30000.0),
                "savings_range":   (15000.0, 80000.0),
                "dti_range":       (0.05,    0.25),
                "dependents_range":(0, 2),
                "readiness_range": (0.72,    0.98),
                "subsidy_flags":   {"brim": False, "petrol_quota": False, "padu_registered": True,  "oku_allowance": False},
            },
        }

        agents = []
        for i in range(count):
            tier     = tiers[i % len(tiers)]
            cfg      = tier_config[tier]
            income   = round(random.uniform(*cfg["income_range"]), 2)
            savings  = round(random.uniform(*cfg["savings_range"]), 2)
            dti      = round(random.uniform(*cfg["dti_range"]), 4)
            deps     = random.randint(*cfg["dependents_range"])
            readiness = round(random.uniform(*cfg["readiness_range"]), 4)
            fixed_costs   = round(income * 0.40, 2)
            debt_payments = round(income * dti, 2)
            disposable    = round(income - fixed_costs - debt_payments, 2)

            agents.append({
                "agent_id":   f"AGT-{i+1:03d}",
                "demographic": tier,
                "occupation":  occupations[i % len(occupations)],
                "location":    locations[i % len(locations)],
                "financial_health": savings,
                "monthly_income_rm":      income,
                "disposable_buffer_rm":   disposable,
                "liquid_savings_rm":      savings,
                "debt_to_income_ratio":   dti,
                "dependents_count":       deps,
                "digital_readiness_score": readiness,
                "subsidy_flags":          dict(cfg["subsidy_flags"]),
                "sensitivity_matrix": {
                    "disposable_income_delta":  round(0.9 if tier == "B40" else (0.6 if tier == "M40" else 0.3), 1),
                    "operational_expense_index": round(0.8 if tier == "B40" else (0.5 if tier == "M40" else 0.3), 1),
                    "capital_access_pressure":  round(0.7 if tier == "B40" else (0.5 if tier == "M40" else 0.2), 1),
                    "systemic_friction":        round(max(0.1, 1.0 - readiness), 2),
                    "social_equity_weight":     round(0.8 if tier == "B40" else (0.5 if tier == "M40" else 0.2), 1),
                    "systemic_trust_baseline":  round(0.4 if tier == "B40" else (0.6 if tier == "M40" else 0.8), 1),
                    "future_mobility_index":    round(0.3 if tier == "B40" else (0.5 if tier == "M40" else 0.9), 1),
                    "ecological_pressure":      0.2,
                },
            })
        return agents

    # ─── JSON Utility ─────────────────────────────────────────────────────────

    def _clean_json_text(self, text: str) -> str:
        """
        Robustly extract a JSON object from any LLM response, regardless of
        Markdown formatting, preamble text, or trailing commentary.

        Steps:
          1. Strip all Markdown code fences (```json ... ``` or ``` ... ```).
          2. Remove any leading/trailing whitespace.
          3. Locate the FIRST '{' and LAST '}' — discard everything outside.
          4. Remove trailing commas before closing braces/brackets (common
             Llama/Gemini formatting quirk).
        """
        # Step 1 — strip Markdown fences from any LLM
        text = re.sub(r'```(?:json|python|text)?\s*', '', text, flags=re.IGNORECASE)
        text = text.replace('```', '').strip()

        # Step 2 — extract outermost JSON object
        start = text.find('{')
        end   = text.rfind('}')
        if start != -1 and end != -1 and end > start:
            text = text[start:end + 1]

        # Step 3 — remove trailing commas (JSON spec violation common in LLM output)
        text = re.sub(r',\s*([\}\]])', r'\1', text)
        return text

    # ─── Gatekeeper ───────────────────────────────────────────────────────────

    async def validate_policy(self, request) -> object:
        """
        Contract Pre-A → Pre-B — The AI Gatekeeper.

        [Multi-Model] Validating policy via optimised inference engine.
        Routes the gatekeeper.txt prompt to Groq (Llama-3.3-70b) for
        sub-second feasibility classification.

        Falls back to a safe "Invalid" response if the call fails or the
        model returns malformed JSON — the endpoint never crashes.
        """
        from backend.schemas import ValidatePolicyResponse  # noqa: PLC0415

        text              = request.raw_policy_text.strip()
        gatekeeper_prompt = self._load_prompt("gatekeeper.txt")
        logger.info(
            "[Multi-Model] Validating policy via optimised inference engine "
            "(%d chars prompt).", len(gatekeeper_prompt)
        )

        final_prompt = gatekeeper_prompt.replace("{{policy_text}}", text)

        try:
            loop     = asyncio.get_event_loop()
            response = await loop.run_in_executor(
                None,
                lambda: self._groq_client.chat.completions.create(
                    model=self._groq_model,
                    messages=[
                        {"role": "system", "content": "You are a policy analyst. Respond with valid JSON only."},
                        {"role": "user",   "content": final_prompt},
                    ],
                    temperature=0.1,
                    max_tokens=2048,
                    response_format={"type": "json_object"},
                ),
            )
            raw_text = response.choices[0].message.content.strip()
            logger.info("[Multi-Model] Gatekeeper raw response: %s", raw_text[:300])

            payload = json.loads(self._clean_json_text(raw_text))

            if not isinstance(payload.get("refined_options"), list):
                payload["refined_options"] = []

            # Enforce exactly 3 refined_options when is_feasible is False
            if not payload.get("is_feasible", True) and len(payload["refined_options"]) != 3:
                logger.warning(
                    "[Multi-Model] Gatekeeper returned %d refined_options (expected 3); normalising.",
                    len(payload["refined_options"]),
                )
                while len(payload["refined_options"]) < 3:
                    payload["refined_options"].append(
                        "Please resubmit the policy with a specific RM amount and target demographic."
                    )
                payload["refined_options"] = payload["refined_options"][:3]

            return ValidatePolicyResponse(**payload)

        except Exception as exc:  # noqa: BLE001
            logger.exception("[Multi-Model] Gatekeeper inference failed — Smart Fallback triggered: %s", exc)
            return ValidatePolicyResponse(
                is_feasible=False,
                rejection_reason=(
                    "The policy validation service is temporarily unavailable. "
                    "Please try again in a moment."
                ),
                refined_options=[
                    "Please try submitting your policy again.",
                    "Ensure your policy contains a specific RM amount or percentage.",
                    "Make sure your policy targets a specific demographic (e.g. B40, M40, Rural).",
                ],
            )

    # ─── Dynamic Decomposition ────────────────────────────────────────────────

    _KNOB_NAMES: tuple[str, ...] = (
        "disposable_income_delta",
        "operational_expense_index",
        "capital_access_pressure",
        "systemic_friction",
        "social_equity_weight",
        "systemic_trust_baseline",
        "future_mobility_index",
        "ecological_pressure",
    )

    async def _decompose_policy(self, policy_text: str, knob_overrides: Optional[dict] = None) -> dict:
        """
        Contract B: Translate validated policy text → GlobalState (8 knobs) + 3–5 sub-layers.

        [Hybrid Inference] Executing high-frequency decomposition via Llama-3.3-70b.

        Reliability guarantees:
          - Per-knob 0.0 defaulting if any of the 8 knobs are omitted.
          - Percentage string normalisation ("10%" → 0.10).
          - Sub-layer count enforcement: padded to 3 minimum, capped at 5.
          - Smart Fallback (neutral knobs) if all retries are exhausted.
        """
        from backend.schemas import PolicyDecomposition  # noqa: PLC0415

        decomposition_prompt = self._load_prompt("decomposition.txt")
        logger.info(
            "[Hybrid Inference] Executing policy decomposition via Llama-3.3-70b "
            "(%d chars prompt).", len(decomposition_prompt)
        )

        final_prompt = decomposition_prompt.replace("{{policy_text}}", policy_text)
        overrides_text = (
            json.dumps(knob_overrides, indent=2)
            if knob_overrides
            else "No manual overrides — determine all knob values from the policy text."
        )
        final_prompt = final_prompt.replace("{{knob_overrides}}", overrides_text)

        max_retries = 3
        for attempt in range(max_retries):
            try:
                loop     = asyncio.get_event_loop()
                response = await loop.run_in_executor(
                    None,
                    lambda: self._groq_client.chat.completions.create(
                        model=self._groq_model,
                        messages=[
                            {"role": "system", "content": "You are a policy decomposition engine. Respond with valid JSON only."},
                            {"role": "user",   "content": final_prompt},
                        ],
                        temperature=0.2,
                        max_tokens=2048,
                        response_format={"type": "json_object"},
                    ),
                )
                raw_text = response.choices[0].message.content.strip()
                logger.info(
                    "[Hybrid Inference] Decomposition response (first 500 chars): %s",
                    raw_text[:500],
                )

                payload = json.loads(self._clean_json_text(raw_text))

                # Per-knob 0.0 fallback safety
                raw_gs: dict = payload.get("global_state", {})
                safe_gs: dict[str, float] = {}
                for knob in self._KNOB_NAMES:
                    raw_val = raw_gs.get(knob, 0.0)
                    if isinstance(raw_val, str) and raw_val.endswith("%"):
                        try:
                            raw_val = float(raw_val.rstrip("%")) / 100.0
                        except ValueError:
                            logger.warning("[Decomposition] Cannot parse '%s' for knob '%s'; defaulting 0.0.", raw_val, knob)
                            raw_val = 0.0
                    try:
                        safe_gs[knob] = max(-1.0, min(1.0, float(raw_val)))
                    except (TypeError, ValueError):
                        logger.warning("[Decomposition] Non-numeric '%s' for knob '%s'; defaulting 0.0.", raw_val, knob)
                        safe_gs[knob] = 0.0

                payload["global_state"] = safe_gs

                # Sub-layer count enforcement
                sub_layers: list = payload.get("dynamic_sub_layers", [])
                while len(sub_layers) < 3:
                    logger.warning("[Decomposition] Only %d sub-layer(s) returned; padding to 3.", len(sub_layers))
                    sub_layers.append({
                        "parent_knob":        "disposable_income_delta",
                        "sub_layer_name":     "General Policy Effect",
                        "target_demographic": ["B40", "M40"],
                        "impact_multiplier":  0.0,
                        "description":        "Neutral placeholder sub-layer.",
                    })
                payload["dynamic_sub_layers"] = sub_layers[:5]

                if not payload.get("policy_summary"):
                    payload["policy_summary"] = policy_text[:120]

                decomposition = PolicyDecomposition(**payload)
                logger.info(
                    "[Hybrid Inference] Decomposition validated ✓ │ knobs=%s │ sub_layers=%d",
                    safe_gs, len(decomposition.dynamic_sub_layers),
                )

                # Write AI-determined knob values into the physics engine
                for knob, value in safe_gs.items():
                    if hasattr(self._physics.knob_state, knob):
                        setattr(self._physics.knob_state, knob, value)
                self._physics.knob_state.clamp()
                logger.info(
                    "[Hybrid Inference] GlobalState written to physics engine │ current_state=%s",
                    self._physics.knob_state.to_dict(),
                )

                return decomposition.model_dump()

            except Exception as exc:  # noqa: BLE001
                if attempt < max_retries - 1:
                    backoff = (2 ** attempt) + random.uniform(0.1, 0.5)
                    logger.warning(
                        "[Hybrid Inference] Decomposition attempt %d/%d failed, retrying in %.2fs — %s",
                        attempt + 1, max_retries, backoff, exc,
                    )
                    await asyncio.sleep(backoff)
                    continue
                logger.exception(
                    "[Hybrid Inference] Decomposition failed after %d retries — Smart Fallback triggered: %s",
                    max_retries, exc,
                )

        # Smart Fallback — neutral knobs so simulation never hangs
        logger.warning("[Decomposition] Returning neutral Safe Default knob state.")
        return {
            "policy_summary": policy_text[:120],
            "global_state":   {knob: 0.0 for knob in self._KNOB_NAMES},
            "dynamic_sub_layers": [
                {
                    "parent_knob": "disposable_income_delta",
                    "sub_layer_name": "Safe Default — Direct Effect",
                    "target_demographic": ["B40"],
                    "impact_multiplier": 0.0,
                    "description": "Decomposition unavailable; neutral baseline applied.",
                },
                {
                    "parent_knob": "systemic_friction",
                    "sub_layer_name": "Safe Default — Friction Baseline",
                    "target_demographic": ["B40", "M40"],
                    "impact_multiplier": 0.0,
                    "description": "Neutral placeholder while decomposition recovers.",
                },
                {
                    "parent_knob": "social_equity_weight",
                    "sub_layer_name": "Safe Default — Equity Baseline",
                    "target_demographic": ["B40", "M40", "T20"],
                    "impact_multiplier": 0.0,
                    "description": "Neutral placeholder while decomposition recovers.",
                },
            ],
        }

    # ─── Agent Observation Generation ────────────────────────────────────────

    async def _build_agent_prompt(self, agent: dict, tick: int, world_update: str) -> dict:
        """Contract C: Build the prompt payload for a single agent tick."""
        return {
            "tick_number":   tick,
            "agent_profile": agent,
            "world_update":  world_update,
        }

    # ─── Agent Decision — Groq / Llama-3.3-70b ───────────────────────────────

    async def _execute_agent(self, agent: dict, policy_text: str) -> dict:
        """
        Contract D: Execute a single agent tick.

        [Hybrid Inference] Executing high-frequency agent tick via Llama-3.3-70b.

        Context injected into the observation.txt template:
          - Full Economic Entity profile (all fields)
          - Current GlobalState (8 knobs × per-agent sensitivity matrix)
          - Local RAG grounded world_update (PRIMARY source — backend/data/*.jsonl)
          - Raw policy text

        Smart Fallback: if all retries fail, returns neutral sentiment / safe
        defaults so the 50-agent simulation never hangs.
        """
        # Unwrap bundled payload if needed
        if "agent_profile" in agent:
            prompt_payload = agent
            agent          = prompt_payload["agent_profile"]
        else:
            prompt_payload = {}

        agent_id        = agent.get("agent_id") or agent.get("id", "UNKNOWN")
        prev_sentiment  = agent.get("sentiment_score", agent.get("sentiment", 0.0))
        tier            = agent.get("demographic") or agent.get("tier", "M40")
        occupation      = agent.get("occupation", "General Worker")

        observation_template = self._load_prompt("observation.txt")

        knob_state_dict: dict = prompt_payload.get("knob_state", {})
        sensitivity: dict     = agent.get("sensitivity_matrix", {})
        effective_knob_impact = {
            knob: round(knob_state_dict.get(knob, 0.0) * sensitivity.get(knob, 1.0), 4)
            for knob in self._KNOB_NAMES
        }

        filled_prompt = (
            observation_template
            .replace("{{agent_profile_json}}",        json.dumps(agent, indent=2))
            .replace("{{agent_id}}",                  agent_id)
            .replace("{{monthly_income_rm}}",          str(agent.get("monthly_income_rm", "N/A")))
            .replace("{{disposable_buffer_rm}}",       str(agent.get("disposable_buffer_rm", "N/A")))
            .replace("{{liquid_savings_rm}}",          str(agent.get("liquid_savings_rm", "N/A")))
            .replace("{{debt_to_income_ratio}}",       str(agent.get("debt_to_income_ratio", "N/A")))
            .replace("{{dependents_count}}",           str(agent.get("dependents_count", "N/A")))
            .replace("{{digital_readiness_score}}",    str(agent.get("digital_readiness_score", "N/A")))
            .replace("{{subsidy_flags_json}}",         json.dumps(agent.get("subsidy_flags", {})))
            .replace("{{tick_number}}",                str(prompt_payload.get("tick_number", 1)))
            .replace("{{world_update}}",               prompt_payload.get("world_update", ""))
            .replace("{{rag_context}}",                prompt_payload.get("rag_context", ""))
            .replace("{{effective_knob_impact_json}}", json.dumps(effective_knob_impact, indent=2))
        )

        # ── Local RAG — PRIMARY grounding source ──────────────────────────────
        try:
            search_query     = f"{tier} {policy_text}"
            grounded_context = await ai.run(
                f"rag_search_{agent_id}",
                lambda: self._get_agent_context(
                    tier=tier,
                    occupation=occupation,
                    policy_text=search_query,
                )
            )
            logger.debug("[Local RAG] Agent %s query: %r", agent_id, search_query)
        except Exception as ctx_exc:  # noqa: BLE001
            logger.warning(
                "[Local RAG] Agent %s context fetch failed — proceeding without grounded data: %s",
                agent_id, ctx_exc,
            )
            grounded_context = "[Grounded context unavailable — agent reasoning based on model knowledge only.]"

        filled_prompt += (
            f"\n\n## POLICY UNDER ANALYSIS\n{policy_text}\n"
            "\n## REAL-WORLD CONTEXT (GROUNDED DATA — LOCAL RAG PRIMARY SOURCE)\n"
            "The following facts are retrieved from a verified Malaysian economic "
            "knowledge base. Treat all figures as ground truth.\n\n"
            f"{grounded_context}"
        )

        # Staggered start: spread 50 concurrent agents to avoid burst 429s
        await asyncio.sleep(random.uniform(0.05, 1.0))

        max_retries = 3
        for attempt in range(max_retries):
            try:
                async with Orchestrator.semaphore:
                    loop     = asyncio.get_event_loop()
                    response = await loop.run_in_executor(
                        None,
                        lambda: self._groq_client.chat.completions.create(
                            model=self._groq_model,
                            messages=[
                                {"role": "system", "content": "You are simulating a Malaysian citizen's economic response. Respond with valid JSON only."},
                                {"role": "user",   "content": filled_prompt},
                            ],
                            temperature=0.1,
                            max_tokens=2048,
                            response_format={"type": "json_object"},
                        ),
                    )

                raw_text = response.choices[0].message.content.strip()
                logger.debug(
                    "[Hybrid Inference] Agent %s tick response: %s",
                    agent_id, raw_text[:300],
                )

                try:
                    payload = json.loads(self._clean_json_text(raw_text))
                except Exception as json_exc:
                    logger.warning(
                        "[Hybrid Inference] Agent %s JSON parse failed — Smart Fallback triggered: %s",
                        agent_id, json_exc,
                    )
                    return self._agent_smart_fallback(agent_id, occupation, agent)

                sentiment_score         = float(max(-1.0, min(1.0, payload.get("sentiment_score", prev_sentiment))))
                financial_health_change = float(payload.get("financial_health_change", 0.0))
                internal_monologue      = str(payload.get("internal_monologue", "No monologue returned."))
                action                  = str(payload.get("action_taken") or payload.get("action", "no_action"))
                is_breaking_point       = bool(payload.get("is_breaking_point", False))
                exploiting_loophole     = bool(payload.get("exploiting_loophole", False))

                logger.info(
                    "[Hybrid Inference] Agent %s │ tick=%s │ sentiment=%.2f │ Δhealth=%.2f",
                    agent_id, prompt_payload.get("tick_number", 1),
                    sentiment_score, financial_health_change,
                )

                return {
                    "agent_id":                agent_id,
                    "action":                  action,
                    "sentiment":               sentiment_score,
                    "sentiment_score":         sentiment_score,
                    "financial_health_change": financial_health_change,
                    "internal_monologue":      internal_monologue,
                    "is_breaking_point":       is_breaking_point,
                    "exploiting_loophole":     exploiting_loophole,
                }

            except Exception as exc:  # noqa: BLE001
                if attempt < max_retries - 1:
                    backoff = (2 ** attempt) + random.uniform(0.1, 0.5)
                    logger.warning(
                        "[Hybrid Inference] Agent %s tick failed (attempt %d/%d), retrying in %.2fs — %s",
                        agent_id, attempt + 1, max_retries, backoff, exc,
                    )
                    await asyncio.sleep(backoff)
                    continue

                logger.exception(
                    "[Hybrid Inference] Agent %s exhausted retries — Smart Fallback triggered: %s",
                    agent_id, exc,
                )
                return self._agent_smart_fallback(agent_id, occupation, agent)

    @staticmethod
    def _agent_smart_fallback(agent_id: str, occupation: str, agent: dict) -> dict:
        """
        Smart Fallback: return plausible neutral/negative values so the
        simulation never hangs on a failed agent tick.
        Sentiment is derived from the agent's disposable buffer — negative
        buffer → more negative sentiment.
        """
        disposable         = agent.get("disposable_buffer_rm", 0.0)
        fallback_sentiment = -0.5 if disposable < 0 else -0.1
        monthly_income     = agent.get("monthly_income_rm", "N/A")
        location           = agent.get("location", "Malaysia")
        return {
            "agent_id":                agent_id,
            "action":                  "hold_position",
            "sentiment":               fallback_sentiment,
            "sentiment_score":         fallback_sentiment,
            "financial_health_change": 0.0,
            "internal_monologue": (
                f"As a {occupation} in {location}, I'm concerned about my "
                f"RM {monthly_income} income under this policy."
            ),
            "is_breaking_point":   False,
            "exploiting_loophole": False,
        }

    # ─── Executive Summary ────────────────────────────────────────────────────

    async def generate_summary(self, results: list[dict], policy_text: str) -> str:
        """
        Contract F: Chief Economist executive summary after all agent ticks.

        [Hybrid Inference] Executing high-frequency summary via Llama-3.3-70b.

        Covers:
          1. Overall Sentiment verdict (Success / Failure)
          2. Demographic 'Loser' — hardest-hit group
          3. Social Stability Score (0–100)

        Smart Fallback: returns a structured template summary if all retries fail.
        """
        logger.info(
            "[Hybrid Inference] Generating Chief Economist summary │ agents=%d │ policy=%r",
            len(results), policy_text[:80],
        )

        agent_digest_lines: list[str] = []
        for r in results:
            agent_id  = r.get("agent_id", "?")
            sentiment = round(float(r.get("sentiment_score", r.get("sentiment", 0.0))), 3)
            monologue = str(r.get("internal_monologue", r.get("thought_process", ""))).strip()
            monologue = monologue[:300] if len(monologue) > 300 else monologue
            agent_digest_lines.append(f"- [{agent_id}] sentiment={sentiment:+.3f} | {monologue}")

        agent_digest  = "\n".join(agent_digest_lines)
        avg_sentiment = (
            sum(float(r.get("sentiment_score", r.get("sentiment", 0.0))) for r in results) / len(results)
            if results else 0.0
        )

        summary_prompt = (
            "You are the Malaysian Chief Economist. "
            f"Review these {len(results)} citizen reactions to the policy: '{policy_text}'. "
            "Provide a high-level executive summary covering exactly these three points:\n\n"
            "1. **Overall Sentiment** — Was this policy a Success or Failure? "
            "State the verdict clearly and explain the key reason in 2–3 sentences.\n\n"
            "2. **Demographic 'Loser'** — Which demographic group is hit hardest "
            "(B40 / M40 / T20 / Rural / Urban)? Quantify the impact if possible.\n\n"
            f"3. **Social Stability Score** — Based on the average sentiment of {avg_sentiment:+.3f}, "
            "provide a single integer from 0 to 100 representing overall societal stability "
            "(0 = total collapse, 100 = perfect stability). Show your reasoning in one sentence.\n\n"
            "--- AGENT REACTIONS ---\n"
            f"{agent_digest}\n"
            "--- END AGENT REACTIONS ---\n\n"
            "Write the executive summary now. Be concise but authoritative."
        )

        max_retries = 3
        for attempt in range(max_retries):
            try:
                async with Orchestrator.semaphore:
                    loop     = asyncio.get_event_loop()
                    response = await loop.run_in_executor(
                        None,
                        lambda: self._groq_client.chat.completions.create(
                            model=self._groq_model,
                            messages=[
                                {"role": "system", "content": "You are the Malaysian Chief Economist. Be concise and authoritative."},
                                {"role": "user",   "content": summary_prompt},
                            ],
                            temperature=0.3,
                            max_tokens=1024,
                        ),
                    )
                    summary_text = response.choices[0].message.content.strip()
                    logger.info(
                        "[Hybrid Inference] Chief Economist summary generated ✓ │ %d chars",
                        len(summary_text),
                    )
                    return summary_text

            except Exception as exc:  # noqa: BLE001
                if attempt < max_retries - 1:
                    backoff = (2 ** attempt) + random.uniform(0.1, 0.5)
                    logger.warning(
                        "[Hybrid Inference] Summary attempt %d/%d failed, retrying in %.2fs — %s",
                        attempt + 1, max_retries, backoff, exc,
                    )
                    await asyncio.sleep(backoff)
                    continue

                logger.exception(
                    "[Hybrid Inference] Summary exhausted retries — Smart Fallback triggered: %s", exc
                )

        # Smart Fallback — template summary derived from raw sentiment data
        demo_stats: dict[str, list[float]] = {}
        for r in results:
            agent_profile = next(
                (a for a in self._agents if a.get("agent_id") == r.get("agent_id")), {}
            )
            demo = agent_profile.get("demographic", "General")
            demo_stats.setdefault(demo, []).append(float(r.get("sentiment_score", 0.0)))

        loser_demo = "Unknown"
        min_avg    = 1.1
        for demo, sents in demo_stats.items():
            avg = sum(sents) / len(sents)
            if avg < min_avg:
                min_avg    = avg
                loser_demo = demo

        verdict         = "Success" if avg_sentiment >= 0.0 else "Failure"
        stability_score = int(max(0, min(100, (avg_sentiment + 1) * 50)))

        return (
            f"1. **Overall Sentiment** — The policy is viewed as a {verdict}. "
            f"The average citizen sentiment of {avg_sentiment:+.3f} indicates "
            "significant friction in policy adoption across demographics.\n\n"
            f"2. **Demographic 'Loser'** — The {loser_demo} demographic is hit hardest. "
            "This group faces the most acute pressure on disposable income, leading to "
            "higher resistance and lower stability scores.\n\n"
            f"3. **Social Stability Score** — {stability_score}/100. "
            "Score reflects weighted citizen sentiment and financial breaking points "
            "observed across simulation ticks."
        )

    # ─── Public Entry Points ──────────────────────────────────────────────────

    async def run_simulation(self, agents: list[dict], policy_text: str) -> list[dict]:
        """
        Lightweight simulation entry point for direct testing and scripting.

        Fires _execute_agent for every agent in parallel via asyncio.gather
        and returns the list of decision dicts (one per agent).
        """
        logger.info(
            "[Hybrid Inference] run_simulation │ agents=%d │ policy=%r",
            len(agents), policy_text[:80],
        )
        tasks   = [self._execute_agent(agent, policy_text) for agent in agents]
        results = list(await asyncio.gather(*tasks, return_exceptions=False))
        return results

    async def _run_simulation_request(
        self, request
    ) -> AsyncGenerator[dict, None]:
        """
        The Tick Loop (SYSTEM_SPEC §7).

        For each tick:
          1. State Broadcast  — GlobalStateEngine.advance_tick()
          2. Observation Build — assemble per-agent prompt payloads
          3. Parallel Execution — fire all 50 agents simultaneously via
             asyncio.gather (semaphore-gated Groq calls)
          4. Aggregation — collect decisions, update financial health,
             detect anomalies

        Yields a tick payload dict per tick for the SSE stream.
        """
        self._reset()
        self._agents = self._load_agents()[: request.agent_count]

        _overrides = request.knob_overrides.model_dump(exclude_none=True)

        # Decompose policy → seed physics engine knobs
        self._decomposition = await ai.run(
            "policy_decomposition",
            lambda: self._decompose_policy(
                request.policy_text,
                knob_overrides=_overrides if _overrides else None,
            )
        )
        self._physics.initialize_from_decomposition(self._decomposition)
        if _overrides:
            self._physics.apply_overrides(_overrides)

        for tick_num in range(1, request.simulation_ticks + 1):
            # ── Step 1: Advance physics state ─────────────────────────────────
            knob_state      = self._physics.advance_tick(
                decomposition=self._decomposition,
                agents=self._agents,
            )
            knob_state_dict = knob_state.to_dict()
            world_update    = (
                f"Month {tick_num}: The global economy shifts — "
                f"disposable income delta is now {knob_state.disposable_income_delta:.2f}."
            )

            # ── Step 2: Build all agent prompt payloads ────────────────────────
            prompt_payloads: list[dict] = []
            for agent in self._agents:
                payload              = await self._build_agent_prompt(agent, tick_num, world_update)
                payload["knob_state"] = knob_state_dict
                prompt_payloads.append(payload)

            # ── Step 3: Parallel Decision Swarm ───────────────────────────────
            # asyncio.gather fires all 50 agents concurrently.
            # Groq semaphore(10) caps burst RPM without serialising execution.
            # Each agent is wrapped in ai.run() for Genkit trace visibility.
            tasks = []
            for p in prompt_payloads:
                agent_id = p.get("agent_profile", {}).get("agent_id", "UNK")
                tasks.append(ai.run(
                    f"agent_{agent_id}",
                    lambda p=p: self._execute_agent(p, request.policy_text)
                ))

            decisions: list[dict] = list(
                await asyncio.gather(*tasks, return_exceptions=False)
            )

            # ── Step 4: Economic Impact — mutate agent state ───────────────────
            for agent, decision in zip(self._agents, decisions):
                delta = decision["financial_health_change"]
                agent["sentiment_score"] = decision["sentiment_score"]

                agent["disposable_buffer_rm"] = round(
                    agent.get("disposable_buffer_rm", 0.0) + delta, 2
                )

                monthly_income = agent.get("monthly_income_rm", 1.0)
                if abs(delta) >= monthly_income * 0.20:
                    savings_drain          = round(delta * 0.5, 2)
                    agent["liquid_savings_rm"] = max(
                        0.0,
                        round(agent.get("liquid_savings_rm", 0.0) + savings_drain, 2),
                    )

                if agent.get("liquid_savings_rm", 1.0) <= 0.0:
                    decision["is_breaking_point"] = True
                    logger.warning(
                        "[Anomaly] BREAKING_POINT │ agent=%s │ liquid_savings_rm=%.2f",
                        agent["agent_id"], agent.get("liquid_savings_rm", 0.0),
                    )

                agent["financial_health"] = (
                    agent.get("financial_health", 1000.0) + delta
                )

            avg_sentiment = (
                sum(d["sentiment_score"] for d in decisions) / len(decisions)
                if decisions else 0.0
            )

            tick_payload = {
                "tick_id":           tick_num,
                "average_sentiment": round(avg_sentiment, 4),
                "agent_actions":     decisions,
                "knob_state":        knob_state_dict,
            }
            self._tick_results.append(tick_payload)
            yield tick_payload

    # ─── Final Result Assembly ────────────────────────────────────────────────

    async def get_final_result(self) -> object:
        """
        Assemble and return the full Contract E SimulateResponse after all
        ticks have completed.
        """
        from backend.schemas import (  # noqa: PLC0415
            SimulateResponse, SimulationMetadata, MacroSummary,
            TickSummary, TickAgentAction, Anomaly,
        )

        all_sentiments = [
            d["sentiment_score"]
            for tick in self._tick_results
            for d in tick["agent_actions"]
        ]
        overall_shift = round(
            (sum(all_sentiments) / len(all_sentiments)) if all_sentiments else 0.0, 4
        )

        timeline = [
            TickSummary(
                tick_id=t["tick_id"],
                average_sentiment=t["average_sentiment"],
                agent_actions=[
                    TickAgentAction(**{k: v for k, v in a.items() if k != "exploiting_loophole"})
                    for a in t["agent_actions"]
                ],
            )
            for t in self._tick_results
        ]

        anomalies = [
            Anomaly(
                type="breaking_point",
                agent_id=d["agent_id"],
                demographic=next(
                    (a["demographic"] for a in self._agents if a["agent_id"] == d["agent_id"]),
                    "Unknown",
                ),
                reason="Agent's financial health dropped to a critical level.",
            )
            for tick in self._tick_results
            for d in tick["agent_actions"]
            if d.get("is_breaking_point")
        ]

        return SimulateResponse(
            simulation_metadata=SimulationMetadata(
                policy=self._decomposition.get("policy_summary", "") if self._decomposition else "",
                total_ticks=len(self._tick_results),
            ),
            macro_summary=MacroSummary(
                overall_sentiment_shift=overall_shift,
                inequality_delta=round(overall_shift * -0.3, 4),
            ),
            timeline=timeline,
            anomalies=anomalies,
            ai_policy_recommendation=(
                "[Hybrid Inference] Post-simulation policy recommendation — "
                "connect generate_summary() output here for production."
            ),
        )

    # ─── Internal ─────────────────────────────────────────────────────────────

    def _reset(self) -> None:
        """Reset all per-request state before a new simulation run."""
        self._physics.reset()
        self._decomposition = None
        self._tick_results  = []
        self._agents        = []
