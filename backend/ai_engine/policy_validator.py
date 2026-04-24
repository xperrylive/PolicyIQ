"""
policy_validator.py — PolicyIQ Policy Validator

Multi-Model Hybrid Architecture:
  - All active LLM inference routed to Groq (Llama-3.3-70b) for
    zero-latency, high-concurrency validation.
  - Genkit @define_flow wrappers in orchestrator.py call this class;
    the validator itself is framework-agnostic.

Validates a raw policy text for feasibility and risk before the
simulation pipeline begins (Contract Pre-A → Pre-B).
"""

import asyncio
import json
import logging
import os
import re
from typing import Dict, Any

from groq import Groq

logger = logging.getLogger("policyiq.ai_engine.policy_validator")

# ─── Fallback model constants (standardised) ──────────────────────────────────
_GEMINI_FLASH_FALLBACK = os.getenv("GEMINI_MODEL",     "gemini-1.5-flash-001")
_GROQ_MODEL_DEFAULT    = os.getenv("GROQ_MODEL",       "llama-3.3-70b-versatile")


def _clean_json_text(text: str) -> str:
    """
    Robustly extract a JSON object from any LLM response, regardless of
    Markdown formatting, preamble text, or trailing commentary.

    Steps:
      1. Strip all Markdown code fences (```json / ```python / ``` etc.).
      2. Remove leading/trailing whitespace.
      3. Locate the FIRST '{' and LAST '}' — discard everything outside.
      4. Remove trailing commas before closing braces/brackets (common
         Llama/Gemini formatting quirk that breaks json.loads).
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


class PolicyValidator:
    """
    Validates a policy text via Groq (Llama-3.3-70b) and returns a
    structured feasibility assessment.

    [Multi-Model] Validating policy via optimised inference engine.

    Returns:
        {
            "is_feasible":      bool,
            "rejection_reason": str,
            "refined_options":  list[str]  (up to 3 items)
        }

    Smart Fallback: if all retries are exhausted, returns a safe
    "unavailable" response so the simulation pipeline never hangs.
    """

    def __init__(self) -> None:
        self._model  = os.getenv("GROQ_MODEL", _GROQ_MODEL_DEFAULT)
        self._client = Groq(api_key=os.getenv("GROQ_API_KEY"))
        logger.info(
            "[Multi-Model] PolicyValidator initialised — "
            "active inference engine: Groq / %s",
            self._model,
        )

    async def validate(self, policy_text: str) -> Dict[str, Any]:
        """
        [Multi-Model] Validating policy via optimised inference engine.

        Sends policy_text to Groq (Llama-3.3-70b) with a structured
        JSON-output prompt and parses the response into the standard
        feasibility schema.

        Retry strategy: up to 3 attempts with exponential backoff.
        Smart Fallback triggered after all retries are exhausted.
        """
        prompt = (
            "You are a senior policy analyst performing a feasibility sanity-check "
            "on a proposed government policy.\n\n"
            "Evaluate the following policy and return a JSON object with EXACTLY "
            "these keys:\n"
            "  - is_feasible      : boolean — is the policy fundamentally implementable?\n"
            "  - rejection_reason : string  — if not feasible, explain why; "
            "if feasible, briefly state the main implementation risk.\n"
            "  - refined_options  : array of up to 3 strings — alternative phrasings "
            "or improvements to the policy.\n\n"
            f"Policy Text:\n{policy_text}"
        )

        max_retries = 3
        for attempt in range(max_retries):
            try:
                loop     = asyncio.get_event_loop()
                response = await loop.run_in_executor(
                    None,
                    lambda: self._client.chat.completions.create(
                        model=self._model,
                        messages=[
                            {
                                "role":    "system",
                                "content": (
                                    "You are a senior policy analyst. "
                                    "Always respond with valid JSON only, no markdown."
                                ),
                            },
                            {"role": "user", "content": prompt},
                        ],
                        temperature=0.2,
                        max_tokens=1024,
                        response_format={"type": "json_object"},
                    )
                )
                raw_text = response.choices[0].message.content.strip()
                logger.info(
                    "[Multi-Model] PolicyValidator raw response: %s", raw_text[:300]
                )
                payload = json.loads(_clean_json_text(raw_text))

                return {
                    "is_feasible": bool(payload.get("is_feasible", True)),
                    "rejection_reason": (
                        payload.get("rejection_reason")
                        or f"Policy risk score is {payload.get('risk_score', 5)}/10"
                    ),
                    "refined_options": list(
                        payload.get(
                            "suggested_alternatives",
                            payload.get("refined_options", [])
                        )
                    )[:3],
                }

            except Exception as exc:
                if attempt < max_retries - 1:
                    import random
                    backoff = (2 ** attempt) + random.uniform(0.1, 0.5)
                    logger.warning(
                        "[Multi-Model] PolicyValidator attempt %d/%d failed, "
                        "retrying in %.2fs — %s",
                        attempt + 1, max_retries, backoff, exc,
                    )
                    await asyncio.sleep(backoff)
                    continue

                logger.exception(
                    "[Multi-Model] PolicyValidator exhausted %d retries — "
                    "Smart Fallback triggered: %s",
                    max_retries, exc,
                )

        # Smart Fallback — safe defaults so the pipeline never hangs
        return {
            "is_feasible": False,
            "rejection_reason": (
                "The policy validation service is temporarily unavailable. "
                "Please try again in a moment."
            ),
            "refined_options": [
                "Please try submitting your policy again.",
                "Ensure your policy contains a specific RM amount or percentage.",
                "Make sure your policy targets a specific demographic (e.g. B40, M40, Rural).",
            ],
        }
