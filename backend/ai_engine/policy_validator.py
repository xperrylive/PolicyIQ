import asyncio
import json
import logging
import os
import re
from typing import Dict, Any

from groq import Groq

logger = logging.getLogger("policyiq.ai_engine.policy_validator")


def _clean_json_text(text: str) -> str:
    """
    Strip Markdown code fences, extract the outermost JSON object, and
    remove trailing commas before closing braces/brackets.
    """
    # Remove ```json ... ``` or ``` ... ``` fences
    text = re.sub(r'```(?:json)?\s*', '', text)
    text = text.replace('```', '').strip()

    # Extract outermost JSON object — discard any trailing text outside {}
    start = text.find('{')
    end = text.rfind('}')
    if start != -1 and end != -1 and end > start:
        text = text[start:end + 1]

    # Remove trailing commas before closing braces/brackets
    text = re.sub(r',\s*([\}\]])', r'\1', text)
    return text


class PolicyValidator:
    def __init__(self):
        self._model = os.getenv("GROQ_MODEL", "llama-3.1-8b-instant")
        self._client = Groq(api_key=os.getenv("GROQ_API_KEY"))
        print(f"DEBUG: PolicyValidator initialized using Groq model: {self._model}")

    async def validate(self, policy_text: str) -> Dict[str, Any]:
        """
        Validates policy_text via Groq and returns:
          {"is_feasible": bool, "rejection_reason": str, "refined_options": list}
        """
        prompt = f"""You are a senior policy analyst doing a sanity check on a proposed policy.
Evaluate the feasibility of the following policy.
Return a JSON object with exactly the following keys:
- is_feasible: (boolean) whether the policy is fundamentally feasible to implement.
- rejection_reason: (string) if not feasible, why? If feasible, a brief assessment of implementation risk.
- refined_options: (list of strings) up to 3 alternatives or improvements.

Policy Text:
{policy_text}
"""

        max_retries = 3
        for attempt in range(max_retries):
            try:
                loop = asyncio.get_event_loop()
                response = await loop.run_in_executor(
                    None,
                    lambda: self._client.chat.completions.create(
                        model=self._model,
                        messages=[
                            {"role": "system", "content": "You are a senior policy analyst. Always respond with valid JSON only, no markdown."},
                            {"role": "user", "content": prompt}
                        ],
                        temperature=0.2,
                        max_tokens=1024,
                        response_format={"type": "json_object"},
                    )
                )
                raw_text = response.choices[0].message.content.strip()
                payload = json.loads(_clean_json_text(raw_text))

                return {
                    "is_feasible": bool(payload.get("is_feasible", True)),
                    "rejection_reason": (
                        payload.get("rejection_reason")
                        or f"Policy risk score is {payload.get('risk_score', 5)}/10"
                    ),
                    "refined_options": list(
                        payload.get("suggested_alternatives", payload.get("refined_options", []))
                    )[:3],
                }

            except Exception as e:
                if attempt < max_retries - 1:
                    import random
                    backoff = (2 ** attempt) + random.uniform(0.1, 0.5)
                    logger.warning(
                        "PolicyValidator attempt %d/%d failed, retrying in %.2fs… Error: %s",
                        attempt + 1, max_retries, backoff, e,
                    )
                    await asyncio.sleep(backoff)
                    continue
                logger.exception("PolicyValidator failed after %d retries: %s", max_retries, e)
                print(f"CRITICAL: Validator failed for model {self._model}. Error: {e}")

        # Safe default — returned after all retries exhausted
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
