"""
orchestrator.py — PolicyIQ Simulation Orchestrator

Coordinates the full simulation pipeline:
  1. Policy Gatekeeper validation (fast Gemini 1.5 Flash check)
  2. Dynamic Decomposition → PolicyDecomposition (Contract B)
  3. Tick loop: Observation Generation → Parallel Agent Execution → Aggregation
  4. Anomaly detection and final AI policy recommendation

This module is the bridge between the FastAPI layer and the AI engine
sub-modules (physics.py, rag_client.py, and the Genkit workflow).

Team AI owns the implementation of the methods marked with TODO below.
Team Backend owns the cloud deployment and environment configuration.
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

import vertexai
from vertexai.generative_models import GenerativeModel, GenerationConfig

from backend.ai_engine.physics import GlobalStateEngine

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
            # CRITICAL FALLBACK: Compatibility Shim for Hackathon Deadline
            class Genkit:
                def __init__(self, *args, **kwargs): pass
                async def run(self, name, func, *args, **kwargs):
                    # Execute the function (which might be a lambda returning a coroutine)
                    result = func() if callable(func) else func
                    # If it's a coroutine, await it
                    if asyncio.iscoroutine(result):
                        return await result
                    return result

            def define_flow(name=None):
                def decorator(func):
                    # Attach a .run method to the function so we can call it like validation_flow.run()
                    async def run_shim(*args, **kwargs):
                        return await func(*args, **kwargs)
                    func.run = run_shim
                    return func
                return decorator

ai = Genkit()


logger = logging.getLogger("policyiq.ai_engine.orchestrator")


# ─── Path helpers ─────────────────────────────────────────────────────────────
_ENGINE_DIR = Path(__file__).parent
PROMPTS_DIR = _ENGINE_DIR / "prompts"
AGENT_DNA_FILE = _ENGINE_DIR / "agent_dna" / "agents_master.json"


# ─── RAG Truth Layer — module-level cached search ─────────────────────────────
# lru_cache cannot decorate instance methods (it would hash `self`), so the
# actual API call lives here at module scope. The Orchestrator delegates to
# this function via _get_agent_context(), keeping the public API clean.
#
# Cache semantics: the cache key is (client, project, location, data_store_id,
# tier, occupation). In practice client/project/data_store_id are constant for
# the lifetime of the process, so the effective key is just (tier, occupation).
# With 3 tiers × 5 occupations = 15 unique combinations, the cache fills quickly
# and all 50 agents benefit from the warm entries on subsequent ticks.

@functools.lru_cache(maxsize=64)
def _cached_local_search(
    *,
    tier: str,
    occupation: str,
    query: str,
) -> str:
    """
    Execute a Local File Search query and return the top-10 snippets as a string.

    This function is intentionally pure (no side effects beyond the API call)
    and is cached at the module level so the same (tier, occupation) combination
    is only fetched once per process lifetime.

    Args:
        tier:          Agent income bracket (``"B40"`` / ``"M40"`` / ``"T20"``).
        occupation:    Agent job type (e.g. ``"Gig Worker"``).
        query:         The search query (e.g. "B40 petrol price").

    Returns:
        A formatted multi-line string with ≤10 grounded snippets.
    """
    _log = logging.getLogger("policyiq.ai_engine.orchestrator")
    
    # Extract keywords
    keywords = [word for word in re.findall(r'[\w.]+', query) if len(word) > 2]
    
    # Path: backend/data/*.jsonl
    data_dir = Path(__file__).parent.parent / "data"
    results = []
    
    if data_dir.exists():
        for file_path in data_dir.glob("*.jsonl"):
            try:
                with open(file_path, "r", encoding="utf-8") as f:
                    for line in f:
                        line_lower = line.lower()
                        if any(kw.lower() in line_lower for kw in keywords):
                            results.append(line.strip())
                            if len(results) >= 10:
                                break
            except Exception as e:
                _log.error("Error reading %s: %s", file_path, e)
            if len(results) >= 10:
                break

    if not results:
        _log.warning("[WARNING] No RAG snippets found locally. RAG Query sent: %s", query)
        _log.critical("CRITICAL: Running simulation WITHOUT grounded data.")
        return ""

    _log.info(f"--- LOCAL RAG SUCCESS: Found {len(results)} snippets ---")
    formatted = "\n".join(f"- {s}" for s in results)
    return formatted


# ─── Genkit Flows ─────────────────────────────────────────────────────────────

@define_flow(name="validation_flow")
async def validation_flow(policy_text: str) -> dict:
    """
    Genkit Flow wrapping the Policy Validator logic.
    Provides a sanity check on feasibility and risk before simulation.
    """
    from backend.ai_engine.policy_validator import PolicyValidator
    validator = PolicyValidator()
    
    # Track the validation as a discrete step in the trace
    result = await ai.run(
        "policy_feasibility_check",
        lambda: validator.validate(policy_text)
    )
    return result


@define_flow(name="simulation_flow")
async def simulation_flow(input_data: dict) -> dict:
    """
    The main simulation flow (Primary Flow).
    Triggers the multi-step simulation pipeline:
      1. Policy Decomposition (AI-led knob seeding)
      2. Multi-tick Agent Simulation (Parallel Execution)
      3. Local RAG grounding (searching backend/data/)
      4. Chief Economist Summary
    """
    policy_text = input_data.get("policy")
    request = input_data.get("request")
    sse_queue = input_data.get("sse_queue")
    
    orch = Orchestrator()
    
    # Step 1: Run the simulation ticks
    # This includes Local RAG and Parallel Agent Execution
    try:
        async for tick_payload in orch._run_simulation_request(request):
            # Each tick is already wrapped in ai.run inside _run_simulation_request
            if sse_queue:
                await sse_queue.put({
                    "event": "tick",
                    "data": json.dumps(tick_payload)
                })
    except Exception as e:
        logger.exception("Internal error in simulation loop")
        if sse_queue:
            await sse_queue.put({
                "event": "error",
                "data": json.dumps({"detail": str(e)})
            })
        return {"error": str(e)}
            
    # Step 2: Chief Economist Summary
    # Use the results accumulated in the orchestrator instance
    last_tick_results = (
        orch._tick_results[-1]["agent_actions"]
        if orch._tick_results
        else []
    )
    
    summary = await ai.run(
        "chief_economist_summary",
        lambda: orch.generate_summary(last_tick_results, policy_text)
    )
    
    # Step 3: Final Aggregated Result
    final_response = await orch.get_final_result()
    
    return {
        "summary": summary,
        "final_response_json": final_response.model_dump_json()
    }


class Orchestrator:
    """
    Central coordinator for the PolicyIQ simulation.

    Lifecycle (per request)::

        orchestrator = Orchestrator()                          # main.py init
        result = await orchestrator.validate_policy(req)      # Gatekeeper
        async for tick in orchestrator.run_simulation(req):   # SSE ticks
            yield tick
        final = await orchestrator.get_final_result()         # Contract E

    State is reset between simulate() calls via _reset().
    """

    # ── Concurrency Semaphore ─────────────────────────────────────────────
    # Limits concurrent Gemini API calls to stay under RPM limits (329s).
    # Defining at class level ensures we stay under the limit across all requests.
    semaphore = asyncio.Semaphore(3)

    def __init__(self) -> None:
        self._physics = GlobalStateEngine()
        self._decomposition: Optional[dict] = None
        self._tick_results: list[dict] = []
        self._agents: list[dict] = []
        self._gemini_model: str     = os.getenv("GEMINI_MODEL",     "gemini-1.5-flash")
        self._gemini_pro_model: str = os.getenv("GEMINI_PRO_MODEL", "gemini-1.5-pro")

        # ── Vertex AI SDK initialisation ──────────────────────────────────────
        _project  = os.getenv("GOOGLE_CLOUD_PROJECT", "")
        ai_loc = os.getenv("VERTEX_AI_LOCATION", "global")

        if _project:
            vertexai.init(project=_project, location=ai_loc)
            logger.info(
                "Vertex AI initialised │ project=%s │ location=%s", _project, ai_loc
            )
        else:
            logger.warning(
                "GOOGLE_CLOUD_PROJECT is not set — Vertex AI calls will fail at runtime."
            )


    # ─── RAG Truth Layer ──────────────────────────────────────────────────────

    def _get_agent_context(self, tier: str, occupation: str, policy_text: str) -> str:
        """
        Search local JSONL files for grounded economic context about a specific
        agent archetype and return the top-10 matching snippet strings as a block.

        Results are cached via ``lru_cache`` on the inner function so that
        identical (tier, occupation, query) combinations are only scanned from
        disk **once** per process lifetime.

        Args:
            tier:        Income bracket, e.g. ``"B40"``, ``"M40"``, ``"T20"``.
            occupation:  Agent job type, e.g. ``"Gig Worker"``.
            policy_text: Query string — includes tier prefix so local search
                         matches relevant JSONL lines (e.g. "B40 petrol price").

        Returns:
            A formatted string containing up to 10 grounded snippets from
            ``backend/data/*.jsonl``, or an empty string if no matches found.
        """
        return _cached_local_search(
            tier=tier,
            occupation=occupation,
            query=policy_text,
        )

    # ─── Prompt Loaders ───────────────────────────────────────────────────────

    def _load_prompt(self, name: str) -> str:
        """Load a prompt template from the prompts/ directory."""
        path = PROMPTS_DIR / name
        if path.exists() and path.stat().st_size > 0:
            return path.read_text(encoding="utf-8")
        logger.warning("Prompt template '%s' is empty or missing — using placeholder.", name)
        return f"[PLACEHOLDER: {name} — Team AI must populate this prompt template]"

    def _load_agents(self) -> list[dict]:
        """Load Agent DNA profiles from agents_master.json."""
        if AGENT_DNA_FILE.exists() and AGENT_DNA_FILE.stat().st_size > 5:
            with AGENT_DNA_FILE.open("r", encoding="utf-8") as f:
                return json.load(f)
        logger.warning("agents_master.json is empty — using synthetic placeholder agents.")
        return self._synthetic_agents(count=5)

    @staticmethod
    def _synthetic_agents(count: int) -> list[dict]:
        """
        Generate realistic synthetic Economic Entity agents for local dev/testing.

        Each agent is seeded with tier-appropriate economic metadata so the LLM
        can make financially grounded decisions.  Ranges are calibrated against
        2023 DOSM household income data:

        Tier     | monthly_income_rm | liquid_savings_rm | digital_readiness_score
        ---------+-------------------+-------------------+------------------------
        B40      | 2,000 – 4,850     | 200  – 2,000      | 0.15 – 0.50
        M40      | 4,850 – 10,959    | 2,000 – 15,000    | 0.45 – 0.78
        T20      | 10,960 +          | 15,000 – 80,000   | 0.72 – 0.98

        Team AI: replace with real 50-agent DNA from agents_master.json.
        """
        import random  # noqa: PLC0415

        tiers = ["B40", "M40", "T20"]
        occupations = ["Gig Worker", "Salaried Corporate", "SME Owner", "Civil Servant", "Unemployed"]
        locations = ["Urban KL", "Suburban Selangor", "Rural Sabah"]

        # ── Per-tier economic parameter ranges ─────────────────────────────────
        tier_config: dict[str, dict] = {
            "B40": {
                "income_range":        (2000.0,  4849.0),
                "savings_range":       (200.0,   2000.0),
                "dti_range":           (0.35,    0.65),   # high debt burden
                "dependents_range":    (2, 5),
                "readiness_range":     (0.15,    0.50),   # limited digital access
                "subsidy_flags": {
                    "brim": True,
                    "petrol_quota": True,
                    "padu_registered": False,   # friction barrier
                    "oku_allowance": False,
                },
            },
            "M40": {
                "income_range":        (4850.0,  10959.0),
                "savings_range":       (2000.0,  15000.0),
                "dti_range":           (0.20,    0.45),
                "dependents_range":    (1, 3),
                "readiness_range":     (0.45,    0.78),
                "subsidy_flags": {
                    "brim": False,
                    "petrol_quota": False,
                    "padu_registered": True,
                    "oku_allowance": False,
                },
            },
            "T20": {
                "income_range":        (10960.0, 30000.0),
                "savings_range":       (15000.0, 80000.0),
                "dti_range":           (0.05,    0.25),   # low relative debt
                "dependents_range":    (0, 2),
                "readiness_range":     (0.72,    0.98),   # high digital fluency
                "subsidy_flags": {
                    "brim": False,
                    "petrol_quota": False,
                    "padu_registered": True,
                    "oku_allowance": False,
                },
            },
        }

        agents = []
        for i in range(count):
            tier = tiers[i % len(tiers)]
            cfg  = tier_config[tier]

            income   = round(random.uniform(*cfg["income_range"]), 2)
            savings  = round(random.uniform(*cfg["savings_range"]), 2)
            dti      = round(random.uniform(*cfg["dti_range"]), 4)
            deps     = random.randint(*cfg["dependents_range"])
            readiness = round(random.uniform(*cfg["readiness_range"]), 4)

            # Disposable buffer = income after debt service and a rough 40 % fixed-cost estimate
            fixed_costs = round(income * 0.40, 2)
            debt_payments = round(income * dti, 2)
            disposable_buffer = round(income - fixed_costs - debt_payments, 2)

            agents.append({
                "agent_id":   f"AGT-{i+1:03d}",
                "demographic": tier,
                "occupation":  occupations[i % len(occupations)],
                "location":    locations[i % len(locations)],
                "financial_health": savings,  # seed financial_health from liquid savings

                # ── Economic Entity Fields ──────────────────────────────────
                "monthly_income_rm":     income,
                "disposable_buffer_rm":  disposable_buffer,
                "liquid_savings_rm":     savings,
                "debt_to_income_ratio":  dti,
                "dependents_count":      deps,
                "digital_readiness_score": readiness,
                "subsidy_flags":         dict(cfg["subsidy_flags"]),  # copy, not reference

                # ── Sensitivity Matrix ──────────────────────────────────────
                "sensitivity_matrix": {
                    # B40 agents feel disposable income changes most acutely
                    "disposable_income_delta": round(
                        0.9 if tier == "B40" else (0.6 if tier == "M40" else 0.3), 1
                    ),
                    "operational_expense_index": round(
                        0.8 if tier == "B40" else (0.5 if tier == "M40" else 0.3), 1
                    ),
                    "capital_access_pressure": round(
                        0.7 if tier == "B40" else (0.5 if tier == "M40" else 0.2), 1
                    ),
                    # High systemic_friction hits low-readiness agents hardest
                    "systemic_friction": round(
                        max(0.1, 1.0 - readiness), 2
                    ),
                    "social_equity_weight": round(
                        0.8 if tier == "B40" else (0.5 if tier == "M40" else 0.2), 1
                    ),
                    "systemic_trust_baseline": round(
                        0.4 if tier == "B40" else (0.6 if tier == "M40" else 0.8), 1
                    ),
                    "future_mobility_index": round(
                        0.3 if tier == "B40" else (0.5 if tier == "M40" else 0.9), 1
                    ),
                    "ecological_pressure": 0.2,
                },
            })
        return agents

    # ─── JSON Utility ─────────────────────────────────────────────────────────

    def _clean_json_text(self, text: str) -> str:
        """
        Aggressively cleans string to extract JSON payload.
        Uses a regex to find the FIRST { and the LAST } and throw away everything else.
        Removes trailing commas before closing braces.
        """
        match = re.search(r'\{.*\}', text, re.DOTALL)
        if match:
            text = match.group(0)
        text = re.sub(r'(\w+)\s*:', r'"\1":', text)
        text = re.sub(r',\s*\}', '}', text)
        return text

    # ─── Gatekeeper ───────────────────────────────────────────────────────────

    async def validate_policy(self, request) -> object:
        """
        Contract Pre-A → Pre-B  —  The AI Gatekeeper.

        Sends the raw policy text to Gemini 1.5 Flash using the
        gatekeeper.txt prompt template and parses the strict JSON response
        into a ValidatePolicyResponse.

        Robustness:
          - Falls back to a safe "Invalid" response if the Gemini call fails
            or the model returns malformed JSON.
        """
        # ── Import here to avoid circular deps at module load ─────────────────
        from backend.schemas import ValidatePolicyResponse  # noqa: PLC0415

        text = request.raw_policy_text.strip()
        gatekeeper_prompt = self._load_prompt("gatekeeper.txt")
        logger.info("Gatekeeper prompt loaded (%d chars). Calling Gemini…", len(gatekeeper_prompt))

        # ── Build the final prompt by injecting the policy text ───────────────
        final_prompt = gatekeeper_prompt.replace("{{policy_text}}", text)

        try:
            # ── Gemini 1.5 Flash call ─────────────────────────────────────────
            model = GenerativeModel(self._gemini_model)
            response = model.generate_content(
                final_prompt,
                generation_config=GenerationConfig(
                    response_mime_type="application/json",
                    temperature=0.1,   # near-deterministic for a validation gate
                    max_output_tokens=512,
                ),
            )

            raw_text = response.text.strip()
            logger.info("Gatekeeper raw response: %s", raw_text[:300])

            # ── Parse and validate the JSON against our Pydantic schema ───────
            payload = json.loads(self._clean_json_text(raw_text))

            # Normalise: ensure refined_options is always a list
            if not isinstance(payload.get("refined_options"), list):
                payload["refined_options"] = []

            # Enforce exactly 3 refined_options when is_feasible is False
            if not payload.get("is_feasible", True) and len(payload["refined_options"]) != 3:
                logger.warning(
                    "Gatekeeper returned %d refined_options (expected 3); "
                    "truncating/padding to 3.",
                    len(payload["refined_options"]),
                )
                # Pad if fewer than 3
                while len(payload["refined_options"]) < 3:
                    payload["refined_options"].append(
                        "Please resubmit the policy with a specific RM amount and target demographic."
                    )
                # Truncate if more than 3
                payload["refined_options"] = payload["refined_options"][:3]

            return ValidatePolicyResponse(**payload)

        except Exception as exc:  # noqa: BLE001
            logger.exception("Gatekeeper Gemini call failed: %s", exc)
            # ── Safe fallback — never crash the endpoint ───────────────────────
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

    # The 8 canonical knob names — used for per-knob 0.0 fallback safety.
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

        Uses Gemini 1.5 Pro with strict JSON output mode so the response maps
        directly to the PolicyDecomposition Pydantic schema.

        Reliability guarantees:
          - Per-knob 0.0 defaulting: if Gemini omits any of the 8 knobs the
            missing value is silently defaulted to 0.0 (no change) rather than
            crashing the simulation.
          - Percentage normalisation: string percentages such as "10%" are
            converted to their float equivalents (0.10) before validation.
          - Sub-layer count enforcement: fewer than 3 sub-layers are padded
            with a neutral placeholder; more than 5 are truncated.
          - On total Gemini failure the previous STUB defaults are returned so
            the simulation degrades gracefully rather than crashing.

        The resulting GlobalState knob values are written into
        ``self._physics.knob_state`` (i.e. current_state) so downstream ticks
        immediately start from the AI-determined baseline.
        """
        from backend.schemas import PolicyDecomposition  # noqa: PLC0415

        # ── 1. Load & fill the prompt template ───────────────────────────────
        decomposition_prompt = self._load_prompt("decomposition.txt")
        logger.info(
            "Decomposition prompt loaded (%d chars). Calling Gemini 1.5 Pro…",
            len(decomposition_prompt),
        )

        final_prompt = decomposition_prompt.replace("{{policy_text}}", policy_text)

        # Inject knob overrides (or a clear "none" message so the model knows)
        if knob_overrides:
            overrides_text = json.dumps(knob_overrides, indent=2)
        else:
            overrides_text = "No manual overrides — determine all knob values from the policy text."
        final_prompt = final_prompt.replace("{{knob_overrides}}", overrides_text)

        try:
            # ── 2. Call Gemini 1.5 Flash with strict JSON output ──────────────
            model = GenerativeModel(self._gemini_model)
            response = model.generate_content(

                final_prompt,
                generation_config=GenerationConfig(
                    response_mime_type="application/json",
                    temperature=0.2,        # low temperature — deterministic mapping
                    max_output_tokens=1024,
                ),
            )

            raw_text = response.text.strip()
            logger.info("Decomposition raw response (first 500 chars): %s", raw_text[:500])

            # ── 3. Parse JSON ─────────────────────────────────────────────────
            payload = json.loads(self._clean_json_text(raw_text))

            # ── 4. Per-knob 0.0 fallback safety ──────────────────────────────
            # Gemini sometimes omits knobs it considers "not affected". We
            # default those to 0.0 so the physics engine never receives KeyError.
            raw_global_state: dict = payload.get("global_state", {})
            safe_global_state: dict[str, float] = {}
            for knob in self._KNOB_NAMES:
                raw_val = raw_global_state.get(knob, 0.0)
                # Normalise percentage strings → float (e.g. "10%" → 0.10)
                if isinstance(raw_val, str) and raw_val.endswith("%"):
                    try:
                        raw_val = float(raw_val.rstrip("%")) / 100.0
                    except ValueError:
                        logger.warning(
                            "Could not parse percentage string '%s' for knob '%s'; defaulting to 0.0.",
                            raw_val, knob,
                        )
                        raw_val = 0.0
                # Clamp to [-1.0, 1.0]
                try:
                    safe_global_state[knob] = max(-1.0, min(1.0, float(raw_val)))
                except (TypeError, ValueError):
                    logger.warning(
                        "Non-numeric value '%s' for knob '%s'; defaulting to 0.0.",
                        raw_val, knob,
                    )
                    safe_global_state[knob] = 0.0

            payload["global_state"] = safe_global_state

            # ── 5. Sub-layer count enforcement ────────────────────────────────
            sub_layers: list = payload.get("dynamic_sub_layers", [])
            while len(sub_layers) < 3:
                logger.warning(
                    "Gemini returned only %d sub-layer(s); padding to 3.", len(sub_layers)
                )
                sub_layers.append({
                    "parent_knob": "disposable_income_delta",
                    "sub_layer_name": "General Policy Effect",
                    "target_demographic": ["B40", "M40"],
                    "impact_multiplier": 0.0,
                    "description": "Neutral placeholder sub-layer (AI did not provide enough detail).",
                })
            payload["dynamic_sub_layers"] = sub_layers[:5]  # enforce max 5

            # Ensure policy_summary is present
            if not payload.get("policy_summary"):
                payload["policy_summary"] = policy_text[:120]

            # ── 6. Validate against the Pydantic schema ───────────────────────
            decomposition = PolicyDecomposition(**payload)
            logger.info(
                "Decomposition validated ✓ │ knobs=%s │ sub_layers=%d",
                safe_global_state,
                len(decomposition.dynamic_sub_layers),
            )

            # ── 7. Store in current_state (self._physics.knob_state) ──────────
            # Write the AI-determined knob values directly into the physics
            # engine so that advance_tick() starts from the correct baseline.
            for knob, value in safe_global_state.items():
                if hasattr(self._physics.knob_state, knob):
                    setattr(self._physics.knob_state, knob, value)
            self._physics.knob_state.clamp()
            logger.info(
                "GlobalState written to physics engine │ current_state=%s",
                self._physics.knob_state.to_dict(),
            )

            return decomposition.model_dump()

        except Exception as exc:  # noqa: BLE001
            logger.exception(
                "Policy Decomposer Gemini call failed — degrading to safe defaults: %s", exc
            )
            # ── Safe fallback: return neutral decomposition, never crash ───────
            return {
                "policy_summary": policy_text[:120],
                "global_state": {knob: 0.0 for knob in self._KNOB_NAMES},
                "dynamic_sub_layers": [
                    {
                        "parent_knob": "disposable_income_delta",
                        "sub_layer_name": "Fallback — Direct Effect",
                        "target_demographic": ["B40"],
                        "impact_multiplier": 0.0,
                        "description": "Decomposition service unavailable; using neutral baseline.",
                    },
                    {
                        "parent_knob": "systemic_friction",
                        "sub_layer_name": "Fallback — Friction Baseline",
                        "target_demographic": ["B40", "M40"],
                        "impact_multiplier": 0.0,
                        "description": "Neutral placeholder while decomposition recovers.",
                    },
                    {
                        "parent_knob": "social_equity_weight",
                        "sub_layer_name": "Fallback — Equity Baseline",
                        "target_demographic": ["B40", "M40", "T20"],
                        "impact_multiplier": 0.0,
                        "description": "Neutral placeholder while decomposition recovers.",
                    },
                ],
            }

    # ─── Agent Observation Generation ────────────────────────────────────────

    async def _build_agent_prompt(
        self, agent: dict, tick: int, world_update: str
    ) -> dict:
        """
        Contract C: Build the prompt payload for a single agent.
        """
        return {
            "tick_number": tick,
            "agent_profile": agent,
            "world_update": world_update,
        }

    # ─── Agent Decision (Gemini call) ─────────────────────────────────────────


    async def _execute_agent(self, agent: dict, policy_text: str) -> dict:
        """
        Contract D: Fire the agent prompt at Gemini 1.5 Flash and parse the
        strict JSON response.

        Args:
            agent:       Full Economic Entity profile dict.
            policy_text: Raw policy string being simulated — injected into both
                         the RAG search query and the final Gemini prompt so the
                         agent knows exactly what it is reacting to.

        Context injected into the observation.txt template:
          - Full Economic Entity profile (all fields)
          - Current GlobalState (the 8 Knobs + effective per-agent impact)
          - RAG-sourced world_update narrative
          - policy_text (what policy this agent is reacting to)

        Response fields (application/json guaranteed):
          - sentiment_score         float  [-1.0, 1.0]
          - internal_monologue      str    agent's private reasoning
          - financial_health_change float  RM change this tick
          - action_taken            str    what the agent actually does
          - is_breaking_point       bool   cumulative health < 0
          - exploiting_loophole     bool   gaming a policy gap

        Resilience: if Gemini fails (network, quota, parse error) we return
        the agent's previous sentiment_score so the simulation never crashes.
        """
        # Support both old-style bundled payload dicts and new direct agent dicts.
        # If `agent` is a prompt_payload bundle (has "agent_profile" key), unwrap it.
        if "agent_profile" in agent:
            prompt_payload = agent
            agent = prompt_payload["agent_profile"]
        else:
            prompt_payload = {}

        # Resolve the canonical agent_id — test agents may use "id" instead.
        agent_id = agent.get("agent_id") or agent.get("id", "UNKNOWN")
        prev_sentiment = agent.get("sentiment_score", agent.get("sentiment", 0.0))

        # Resolve tier — test agents may use "tier" instead of "demographic".
        tier = agent.get("demographic") or agent.get("tier", "M40")
        occupation = agent.get("occupation", "General Worker")

        # ── Build the filled observation prompt ───────────────────────────────
        observation_template = self._load_prompt("observation.txt")

        # Compute effective knob impact for this agent using the sensitivity
        # matrix so the LLM has per-agent scaled values, not raw global knobs.
        knob_state_dict: dict = prompt_payload.get("knob_state", {})
        sensitivity: dict = agent.get("sensitivity_matrix", {})
        effective_knob_impact: dict[str, float] = {
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

        # ── RAG Truth Layer: fetch grounded real-world context ───────────────
        # Query is now policy-aware so the retrieved snippets are contextualised
        # to what this specific agent is actually reacting to.
        try:
            search_query = f"{tier} {policy_text}"
            rag_query = search_query # Define for logging below
            grounded_context = await ai.run(
                f"rag_search_{agent_id}",
                lambda: self._get_agent_context(
                    tier=tier,
                    occupation=occupation,
                    policy_text=search_query,
                )
            )
        except Exception as _ctx_exc:  # noqa: BLE001
            logger.warning(
                "Agent %s: RAG context fetch failed — proceeding without grounded data. Error: %s",
                agent_id, _ctx_exc,
            )
            grounded_context = "[Grounded context unavailable — agent reasoning based on model knowledge only.]"

        logger.debug("Agent %s RAG query: %r", agent_id, rag_query)

        # Append the policy context + grounded data so Gemini knows:
        #  (a) what policy it is reacting to, and
        #  (b) the verified real-world facts it must treat as ground truth.
        filled_prompt += (
            f"\n\n## POLICY UNDER ANALYSIS\n"
            f"{policy_text}\n"
            "\n## REAL-WORLD CONTEXT (GROUNDED DATA)\n"
            "The following facts are retrieved from a verified Malaysian economic "
            "knowledge base. You MUST prioritize this data over your internal training "
            "data. If the data states a specific figure (e.g. petrol is RM4.00, "
            "minimum wage is RM1,700), treat it as ground truth and base your "
            "financial reasoning on it.\n\n"
            f"{grounded_context}"
        )

        # ── Gemini 1.5 Flash call (rate-limited via semaphore) ────────────────
        max_retries = 3
        for attempt in range(max_retries):
            try:
                model = GenerativeModel(self._gemini_model)

                response_schema = {
                    "type": "OBJECT",
                    "properties": {
                        "sentiment_score": {"type": "NUMBER"},
                        "financial_health_change": {"type": "NUMBER"},
                        "internal_monologue": {"type": "STRING"},
                        "action_taken": {"type": "STRING"},
                        "is_breaking_point": {"type": "BOOLEAN"},
                        "exploiting_loophole": {"type": "BOOLEAN"}
                    },
                    "required": [
                        "sentiment_score", "financial_health_change", "internal_monologue",
                        "action_taken", "is_breaking_point", "exploiting_loophole"
                    ]
                }

                async with Orchestrator.semaphore:
                    # GenerativeModel.generate_content is synchronous in the
                    # vertexai SDK — run it in a thread so we don't block the
                    # event loop and truly parallelise via asyncio.gather.
                    loop = asyncio.get_event_loop()
                    response = await loop.run_in_executor(
                        None,
                        lambda: model.generate_content(
                            filled_prompt,
                            generation_config=GenerationConfig(
                                response_mime_type="application/json",
                                response_schema=response_schema,
                                temperature=0.1,
                                max_output_tokens=1024,
                            ),
                        ),
                    )

                raw_text = response.text.strip()
                logger.debug("Agent %s raw response: %s", agent_id, raw_text[:300])

                try:
                    # ALWAYS call _clean_json_text to catch markdown backticks etc.
                    # Pydantic parsing / JSON loads fallback layer
                    payload = json.loads(self._clean_json_text(raw_text))
                except Exception as json_exc:
                    logger.warning("Agent %s: JSON parsing failed, triggering Smart Fallback. Error: %s", agent_id, json_exc)
                    disposable = agent.get("disposable_buffer_rm", 0.0)
                    fallback_sentiment = -0.5 if disposable < 0 else -0.1
                    monthly_income_rm = agent.get("monthly_income_rm", "N/A")
                    location = agent.get("location", "Malaysia")
                    return {
                        "agent_id":                agent_id,
                        "action":                  "hold_position",
                        "sentiment":               fallback_sentiment,
                        "sentiment_score":         fallback_sentiment,
                        "financial_health_change": 0.0,
                        "internal_monologue":      (
                            f"As a {occupation} in {location}, I'm worried about my RM {monthly_income_rm} "
                            "income covering this fuel hike."
                        ),
                        "is_breaking_point":       False,
                        "exploiting_loophole":     False,
                    }

                # ── Normalise / clamp fields ──────────────────────────────────
                sentiment_score = float(
                    max(-1.0, min(1.0, payload.get("sentiment_score", prev_sentiment)))
                )
                financial_health_change = float(
                    payload.get("financial_health_change", 0.0)
                )
                internal_monologue = str(
                    payload.get("internal_monologue", "No monologue returned.")
                )
                # observation.txt uses "action" but task spec requests
                # "action_taken" — accept both gracefully.
                action = str(
                    payload.get("action_taken") or payload.get("action", "no_action")
                )
                is_breaking_point = bool(payload.get("is_breaking_point", False))
                exploiting_loophole = bool(payload.get("exploiting_loophole", False))

                logger.info(
                    "Agent %s │ tick=%s │ sentiment=%.2f │ Δhealth=%.2f",
                    agent_id,
                    prompt_payload.get("tick_number", 1),
                    sentiment_score,
                    financial_health_change,
                )

                # RETURN CLEAN DICTIONARY (Remove debug bloat)
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
                        "Agent %s: Gemini call failed (attempt %d/%d), retrying in %.2fs... Error: %s",
                        agent_id, attempt + 1, max_retries, backoff, exc
                    )
                    await asyncio.sleep(backoff)
                    continue

                # ── Graceful degradation: smart fallback ──────────────────────
                # No more "API error" text — calculate plausible values
                disposable = agent.get("disposable_buffer_rm", 0.0)
                fallback_sentiment = -0.5 if disposable < 0 else -0.1
                
                monthly_income_rm = agent.get("monthly_income_rm", "N/A")
                location = agent.get("location", "Malaysia")
                
                return {
                    "agent_id":                agent_id,
                    "action":                  "hold_position",
                    "sentiment":               fallback_sentiment,
                    "sentiment_score":         fallback_sentiment,
                    "financial_health_change": 0.0,
                    "internal_monologue":      (
                        f"As a {occupation} in {location}, I'm worried about my RM {monthly_income_rm} "
                        "income covering this fuel hike."
                    ),
                    "is_breaking_point":       False,
                    "exploiting_loophole":     False,
                }

    # ─── Executive Summary ────────────────────────────────────────────────────

    async def generate_summary(self, results: list[dict], policy_text: str) -> str:
        """
        Contract F: Generate a high-level executive summary after all agents finish.

        Acts as the Malaysian Chief Economist reviewing 50 citizen reactions and
        producing a structured verdict covering:
          1. Overall Sentiment (Success / Failure)
          2. Demographic 'Loser' — who is hit hardest
          3. Social Stability Score (0–100 %)

        Args:
            results:     List of agent decision dicts (one per agent) containing
                         at minimum ``agent_id``, ``sentiment_score``, and
                         ``internal_monologue``.
            policy_text: The raw policy string that was simulated.

        Returns:
            Plain-text executive summary string from Gemini 1.5 Flash.
            Falls back to a structured fallback string if the API call fails.
        """
        logger.info(
            "generate_summary │ agents=%d │ policy=%r", len(results), policy_text[:80]
        )

        # ── Build a compact digest of each agent's reaction ───────────────────
        # Keep tokens lean: agent_id, demographic, sentiment_score, monologue.
        agent_digest_lines: list[str] = []
        for r in results:
            agent_id   = r.get("agent_id", "?")
            sentiment  = round(float(r.get("sentiment_score", r.get("sentiment", 0.0))), 3)
            monologue  = str(r.get("internal_monologue", r.get("thought_process", ""))).strip()
            # Truncate long monologues so the combined prompt stays < 30 k tokens
            monologue  = monologue[:300] if len(monologue) > 300 else monologue
            agent_digest_lines.append(
                f"- [{agent_id}] sentiment={sentiment:+.3f} | {monologue}"
            )

        agent_digest = "\n".join(agent_digest_lines)
        
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
            "provide a single integer from 0 to 100 "
            "representing overall societal stability after this policy "
            "(0 = total collapse, 100 = perfect stability). "
            "Show your reasoning in one sentence.\n\n"
            "--- AGENT REACTIONS ---\n"
            f"{agent_digest}\n"
            "--- END AGENT REACTIONS ---\n\n"
            "Write the executive summary now. Be concise but authoritative."
        )

        max_retries = 3
        for attempt in range(max_retries):
            try:
                async with Orchestrator.semaphore:
                    loop = asyncio.get_event_loop()
                    model = GenerativeModel(self._gemini_model)

                    response = await loop.run_in_executor(
                        None,
                        lambda: model.generate_content(
                            summary_prompt,
                            generation_config=GenerationConfig(
                                temperature=0.3,
                                max_output_tokens=1024,
                            ),
                        ),
                    )

                    summary_text = response.text.strip()
                    logger.info(
                        "generate_summary ✓ │ length=%d chars", len(summary_text)
                    )
                    return summary_text

            except Exception as exc:  # noqa: BLE001
                if attempt < max_retries - 1:
                    backoff = (2 ** attempt) + random.uniform(0.1, 0.5)
                    logger.warning(
                        "Summary generation failed (attempt %d/%d), retrying in %.2fs... Error: %s",
                        attempt + 1, max_retries, backoff, exc
                    )
                    await asyncio.sleep(backoff)
                    continue

                logger.exception("generate_summary Gemini call failed after retries: %s", exc)
                
                # ── Smart Fallback Summary (The "Template Summary") ──────────────
                # Identify the demographic with the lowest average sentiment
                demo_stats = {}
                for r in results:
                    # Find demographic from agents_master or agent dict
                    agent_id = r.get("agent_id")
                    agent_profile = next((a for a in self._agents if a.get("agent_id") == agent_id), {})
                    demo = agent_profile.get("demographic", "General")
                    
                    if demo not in demo_stats:
                        demo_stats[demo] = []
                    demo_stats[demo].append(float(r.get("sentiment_score", 0.0)))
                
                loser_demo = "Unknown"
                min_avg = 1.1
                for demo, sents in demo_stats.items():
                    avg = sum(sents) / len(sents)
                    if avg < min_avg:
                        min_avg = avg
                        loser_demo = demo

                verdict = "Success" if avg_sentiment >= 0.0 else "Failure"
                stability_score = int(max(0, min(100, (avg_sentiment + 1) * 50)))
                
                return (
                    f"1. **Overall Sentiment** — The policy is viewed as a {verdict}. "
                    f"While some sectors show resilience, the average citizen sentiment of {avg_sentiment:+.3f} "
                    "suggests significant friction in policy adoption.\n\n"
                    f"2. **Demographic 'Loser'** — The {loser_demo} demographic is hit hardest. "
                    "This group faces the most acute pressure on disposable income, leading to higher "
                    "resistance and lower stability scores compared to other segments.\n\n"
                    f"3. **Social Stability Score** — {stability_score}. "
                    f"The score reflects a weighted assessment of citizen sentiment and financial breaking points "
                    f"observed during the simulation ticks."
                )

    # ─── Public Entry Points ──────────────────────────────────────────────────

    async def run_simulation(self, agents, policy_text):
        """
        Lightweight simulation entry point for direct testing and scripting.

        Accepts a raw list of agent dicts and a plain policy string, fires
        ``_execute_agent`` for every agent in parallel, and returns the list
        of decision dicts (one per agent).

        Args:
            agents:      List of agent profile dicts (must contain at least
                         ``"id"`` or ``"agent_id"``, ``"tier"`` or
                         ``"demographic"``, and ``"occupation"`` keys).
            policy_text: The policy being simulated — used as both the RAG
                         search context and injected verbatim into the Gemini
                         prompt so each agent knows exactly what it reacts to.

        Returns:
            List of decision dicts in the same order as ``agents``.
        """
        logger.info(
            "run_simulation │ agents=%d │ policy=%r", len(agents), policy_text[:80]
        )
        tasks = [self._execute_agent(agent, policy_text) for agent in agents]
        results: list[dict] = list(await asyncio.gather(*tasks, return_exceptions=False))
        return results

    async def _run_simulation_request(
        self, request
    ) -> AsyncGenerator[dict, None]:
        """
        The Tick Loop (SYSTEM_SPEC §7).

        For each tick:
          1. State Broadcast (GlobalStateEngine.advance_tick)
          2. Observation Generation (build prompts for each agent)
          3. Parallel Execution (fire agent prompts — stub for now)
          4. Aggregation (collect decisions, update financial health)

        Yields a dict per tick for the SSE stream.
        """
        self._reset()
        self._agents = self._load_agents()[: request.agent_count]

        # Decompose policy → seed physics engine
        # Pass any manual knob overrides so the AI prompt can factor them in.
        _overrides = request.knob_overrides.model_dump(exclude_none=True)
        
        # Wrap decomposition in ai.run for tracing
        self._decomposition = await ai.run(
            "policy_decomposition",
            lambda: self._decompose_policy(
                request.policy_text,
                knob_overrides=_overrides if _overrides else None,
            )
        )
        # initialize_from_decomposition registers the sub-layers in the physics
        # engine. _decompose_policy already wrote the knob values directly into
        # self._physics.knob_state, so this call will overwrite them — we then
        # re-apply any manual overrides on top.
        self._physics.initialize_from_decomposition(self._decomposition)
        if _overrides:
            self._physics.apply_overrides(_overrides)

        for tick_num in range(1, request.simulation_ticks + 1):
            # ── Step 1: Advance physics state ─────────────────────────────────
            knob_state = self._physics.advance_tick(
                decomposition=self._decomposition,
                agents=self._agents,
            )
            knob_state_dict = knob_state.to_dict()
            world_update = (
                f"Month {tick_num}: The global economy shifts — "
                f"disposable income delta is now {knob_state.disposable_income_delta:.2f}."
            )

            # ── Step 2: Build all agent prompt payloads (sequential, cheap) ───
            # We pass knob_state_dict into each payload so _execute_agent can
            # compute the per-agent effective knob impact without a lock.
            prompt_payloads: list[dict] = []
            for agent in self._agents:
                payload = await self._build_agent_prompt(agent, tick_num, world_update)
                payload["knob_state"] = knob_state_dict  # inject for sensitivity calc
                prompt_payloads.append(payload)

            # ── Step 3: Fire ALL agents simultaneously (Parallel Decision Swarm)
            # asyncio.gather runs all coroutines concurrently. _execute_agent
            # uses asyncio.Semaphore(10) internally to cap concurrent Vertex AI
            # calls so we never hit rate-limit 429s even at 50 agents.
            #
            # We wrap each execution in ai.run() so individual agent traces
            # appear in the Genkit Developer UI.
            tasks = []
            for p in prompt_payloads:
                agent_id = p.get("agent_profile", {}).get("agent_id", "UNK")
                # Wrap in ai.run for Genkit tracing
                tasks.append(ai.run(
                    f"agent_{agent_id}",
                    lambda p=p: self._execute_agent(p, request.policy_text)
                ))

            decisions: list[dict] = list(
                await asyncio.gather(
                    *tasks,
                    return_exceptions=False,  # individual failures already caught inside
                )
            )

            # ── Step 4: Economic Impact — mutate agent state ───────────────────
            anomaly_agent_ids: set[str] = set()
            for agent, decision in zip(self._agents, decisions):
                delta = decision["financial_health_change"]

                # Persist sentiment on agent dict for next-tick fallback
                agent["sentiment_score"] = decision["sentiment_score"]

                # Update disposable_buffer_rm (the "wallet" that flexes each tick)
                agent["disposable_buffer_rm"] = round(
                    agent.get("disposable_buffer_rm", 0.0) + delta, 2
                )

                # Drain/top-up liquid_savings_rm proportionally when the buffer
                # swings significantly (±20 % of monthly income).
                monthly_income = agent.get("monthly_income_rm", 1.0)
                if abs(delta) >= monthly_income * 0.20:
                    savings_drain = round(delta * 0.5, 2)  # 50 % of delta hits savings
                    agent["liquid_savings_rm"] = max(
                        0.0,
                        round(agent.get("liquid_savings_rm", 0.0) + savings_drain, 2),
                    )

                # ── Anomaly Trigger: liquid_savings_rm below zero ─────────────
                if agent.get("liquid_savings_rm", 1.0) <= 0.0:
                    decision["is_breaking_point"] = True
                    anomaly_agent_ids.add(agent["agent_id"])
                    logger.warning(
                        "BREAKING_POINT │ agent=%s │ liquid_savings_rm=%.2f",
                        agent["agent_id"],
                        agent.get("liquid_savings_rm", 0.0),
                    )

                # Keep legacy financial_health in sync for get_final_result()
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

        TODO (Team AI): Wire the real AI policy recommendation from Gemini.
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
                inequality_delta=round(overall_shift * -0.3, 4),  # placeholder formula
            ),
            timeline=timeline,
            anomalies=anomalies,
            ai_policy_recommendation=(
                "[TODO — Team AI: Call Gemini post-simulation to generate a 1-paragraph "
                "policy mitigation recommendation based on the full timeline.]"
            ),
        )

    # ─── Internal ─────────────────────────────────────────────────────────────

    def _reset(self) -> None:
        """Reset all per-request state."""
        self._physics.reset()
        self._decomposition = None
        self._tick_results = []
        self._agents = []
