### File 2: `SYSTEM_SPEC.md` (Save in your root directory)

```markdown
# 📄 SYSTEM_SPEC.md: PolicyIQ Knowledge Base

## 1. Core Concept & Glossary
**PolicyIQ** is a multi-agent AI simulation designed to stress-test Malaysian government policies before deployment. It translates text-based policies into mathematical vectors, subjects 50 AI "Digital Malaysians" to those vectors across simulated time steps, and tracks their financial and emotional reactions.

* **Global State:** The mathematical representation of the Malaysian economy.
* **The Ticks:** Chronological time steps of the simulation (e.g., Month 1, Month 2).
* **Agent DNA:** The static demographic and psychological profile of a citizen.
* **The Breaking Point:** A state where an agent's financial health drops below zero, or sentiment reaches -1.0.

---

## 2. The Gatekeeper (Policy Validation)
Policies must be viable before simulation. The Gatekeeper runs a fast Gemini 1.5 Flash check.
* If a policy lacks an economic lever or target group, it is rejected.
* The system provides 3 specific, mathematically viable `refined_options` for the user to select instead.

---

## 3. The 8 Universal Knobs (The Physics Engine)
Variables that define the Global State. Values range from `-1.0` to `1.0`. 
1.  **Disposable Income Delta:** Direct cash flow changes. 
2.  **Operational Expense Index:** Cost of existing (e.g., inflation, subsidy cuts).
3.  **Capital Access Pressure:** Debt and borrowing stress (OPR).
4.  **Systemic Friction:** Time poverty and administrative red tape (e.g., PADU registration).
5.  **Social Equity Weight:** Perception of fairness (Gini coefficient impact).
6.  **Systemic Trust Baseline:** Strength of the social contract.
7.  **Future Mobility Index:** Opportunities for upskilling or class mobility.
8.  **Ecological/Resource Pressure:** Sustainability metrics.

---

## 4. Dynamic Decomposition (The Sub-Layers)
Knobs are translated into 3 to 5 concrete "Sub-Layers" specific to the input policy using Gemini.
* **Hard Limit:** Exactly 3 to 5 sub-layers total.
* **Targeting:** Must specify a demographic array (e.g., `["B40", "M40", "Urban"]`).
* **Impact Multiplier:** A specific multiplier to alter the parent knob's effect on the target group.

---

## 5. Agent DNA — Economic Entities (The Digital Malaysians)
Each of the 50 agents is a fully parameterised **Economic Entity**, not merely a demographic label. Static profile fields:

### 5.1 Identity Fields
* **Income Tier:** B40, M40, T20 (mapped to DOSM household income thresholds).
* **Occupation Type:** Gig Worker, Salaried Corporate, SME Owner, Civil Servant, Unemployed.
* **Location Matrix:** Urban, Suburban, Rural.

### 5.2 Sensitivity Matrix
A dictionary assigning a weight (0.0 to 1.0) to each of the 8 Knobs based on the agent's demographic. Tier-calibrated: B40 agents have highest sensitivity to `disposable_income_delta` (0.9) and `systemic_friction` (inversely proportional to `digital_readiness_score`).

### 5.3 Economic Entity Fields (Stream 1 — New)
All new fields are enforced by `AgentProfile` (Pydantic v2, `schemas.py`).

| Field | Type | Constraint | B40 Range | M40 Range | T20 Range |
|---|---|---|---|---|---|
| `monthly_income_rm` | float | > 0 | 2,000–4,849 RM | 4,850–10,959 RM | 10,960–30,000 RM |
| `disposable_buffer_rm` | float | none | derived | derived | derived |
| `liquid_savings_rm` | float | ≥ 0 | 200–2,000 RM | 2,000–15,000 RM | 15,000–80,000 RM |
| `debt_to_income_ratio` | float | ≥ 0 | 0.35–0.65 | 0.20–0.45 | 0.05–0.25 |
| `dependents_count` | int | ≥ 0 | 2–5 | 1–3 | 0–2 |
| `digital_readiness_score` | float | 0.0–1.0 | 0.15–0.50 | 0.45–0.78 | 0.72–0.98 |
| `subsidy_flags` | Dict[str, bool] | — | brim=T, petrol=T | brim=F | brim=F |

`disposable_buffer_rm` is derived: `income − (income × 0.40 fixed costs) − (income × debt_to_income_ratio)`. A negative value means the agent is already running a monthly deficit before any policy effect.

---

## 6. The RAG Pipeline (Data Grounding)
Financial calculations are grounded using Vertex AI Search.
* **The Source:** Cleaned datasets from OpenDOSM and Data.gov.my.
* **The Process:** The backend queries Vertex AI for context (e.g., "Average M40 transport spend in Selangor").
* **Injection:** Factual data is injected into the agent's prompt as `rag_context`.

---

## 7. The Simulation Loop (The Ticks)
1.  **State Broadcast:** Calculate the current environment based on Knobs and Sub-Layers.
2.  **Observation Generation:** Construct a personalized prompt for each agent.
3.  **Parallel Execution:** Firebase Genkit fires all 50 agent prompts to Gemini concurrently.
4.  **The Agent Decision:** Each agent returns a strict JSON payload (Action, sentiment, financial change, monologue).
5.  **Aggregation:** Collect all 50 responses, update Macro Analytics, advance to the next Tick.

---

## 8. The Anomaly Engine & Feedback Loop
* **The Breaking Point:** Flags if an agent's financial health drops to a critical level.
* **Loophole Detection:** Flags agents attempting to exploit policy gaps.
* **AI Policy Tweak:** Post-simulation, Gemini analyzes the timeline and suggests a 1-paragraph policy mitigation.