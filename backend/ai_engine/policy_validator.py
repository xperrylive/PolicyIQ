import os
import json
import logging
from typing import Dict, Any

from vertexai.generative_models import GenerativeModel, GenerationConfig

logger = logging.getLogger("policyiq.ai_engine.policy_validator")

class PolicyValidator:
    def __init__(self):
        self._gemini_model = os.getenv("GEMINI_MODEL", "gemini-1.5-flash")


    async def validate(self, policy_text: str) -> Dict[str, Any]:
        """
        Takes policy_text and returns a JSON object: {"is_feasible": bool, "risk_score": int, "suggested_alternatives": list}
        """
        model = GenerativeModel(self._gemini_model)
        
        prompt = f"""You are a senior policy analyst doing a sanity check on a proposed policy.
Evaluate the feasibility of the following policy.
Return a JSON object with exactly the following keys:
- is_feasible: (boolean) whether the policy is fundamentally feasible to implement.
- rejection_reason: (string) if not feasible, why? If feasible, a brief assessment of implementation risk.
- refined_options: (list of strings) up to 3 alternatives or improvements.

Policy Text:
{policy_text}
"""

        response_schema = {
            "type": "OBJECT",
            "properties": {
                "is_feasible": {"type": "BOOLEAN"},
                "rejection_reason": {"type": "STRING"},
                "refined_options": {
                    "type": "ARRAY",
                    "items": {"type": "STRING"}
                }
            },
            "required": ["is_feasible", "rejection_reason", "refined_options"]
        }

        try:
            import asyncio
            loop = asyncio.get_event_loop()
            response = await loop.run_in_executor(
                None,
                lambda: model.generate_content(
                    prompt,
                    generation_config=GenerationConfig(
                        response_mime_type="application/json",
                        response_schema=response_schema,
                        temperature=0.2,
                        max_output_tokens=1024,
                    ),
                )
            )
            raw_text = response.text.strip()
            
            clean_text = raw_text.strip().replace('```json', '').replace('```', '').strip()
            start_idx = clean_text.find('{')
            end_idx = clean_text.rfind('}')
            if start_idx != -1 and end_idx != -1:
                clean_text = clean_text[start_idx:end_idx+1]
            payload = json.loads(clean_text)
            
            # Normalize to match the requested schema
            return {
                "is_feasible": bool(payload.get("is_feasible", True)),
                "rejection_reason": payload.get("rejection_reason") or f"Policy risk score is {payload.get('risk_score', 5)}/10",
                "refined_options": list(payload.get("suggested_alternatives", payload.get("refined_options", [])))[:3]
            }

        except Exception as e:
            logger.exception(f"PolicyValidator failed: {e}")
            return {
                "is_feasible": False,
                "rejection_reason": "Policy validation service temporarily unavailable.",
                "refined_options": ["Please try submitting your policy again later."]
            }
