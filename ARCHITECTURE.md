# 🏗️ PolicyIQ Architecture
## Technical Deep Dive for Project 2030: MyAI Future Hackathon

---

## 🎯 System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     PolicyIQ Architecture                        │
│                  "SimCity for GovTech"                          │
└─────────────────────────────────────────────────────────────────┘

┌──────────────┐         ┌──────────────┐         ┌──────────────┐
│   Flutter    │  HTTP   │   FastAPI    │  Groq   │  Llama-3.3   │
│  Dashboard   │ ◄─────► │   Backend    │ ◄─────► │   (70B)      │
│  (Dart)      │   SSE   │  (Python)    │   API   │              │
└──────────────┘         └──────────────┘         └──────────────┘
                                │
                                │ RAG
                                ▼
                         ┌──────────────┐
                         │  DOSM Data   │
                         │   (JSONL)    │
                         └──────────────┘
```

---

## 🔄 Data Flow: The Governor's Journey

### Stage 1: Gatekeeper (Policy Validation)

```
User Input
    │
    │ "Make petrol cheaper for poor people"
    ▼
┌─────────────────────────────────────────────────────────────┐
│  Frontend: Gatekeeper Screen                                 │
│  - Text input field                                          │
│  - "Validate Policy" button                                  │
└─────────────────────────────────────────────────────────────┘
    │
    │ POST /validate-policy
    │ Contract Pre-A: {"raw_policy_text": "..."}
    ▼
┌─────────────────────────────────────────────────────────────┐
│  Backend: Orchestrator.validate_policy()                     │
│  1. Load gatekeeper.txt prompt                               │
│  2. Inject policy text                                       │
│  3. Call Groq API (Llama-3.3-70b)                           │
│  4. Parse JSON response                                      │
└─────────────────────────────────────────────────────────────┘
    │
    │ Groq API Call
    ▼
┌─────────────────────────────────────────────────────────────┐
│  Llama-3.3-70b Inference                                     │
│  - Validates specificity (RM amounts, demographics)          │
│  - Checks measurability (can we simulate this?)              │
│  - Verifies grounding (PADU, BSH, EPF references)            │
│  - Generates 3 refined alternatives if rejected              │
│  - Generates 3 strategic suggestions if rejected             │
│  - Creates Environment Blueprint if feasible                 │
└─────────────────────────────────────────────────────────────┘
    │
    │ Contract Pre-B
    ▼
┌─────────────────────────────────────────────────────────────┐
│  Response: ValidatePolicyResponse                            │
│  {                                                            │
│    "is_feasible": false,                                     │
│    "rejection_reason": "Too vague...",                       │
│    "refined_options": ["Option 1", "Option 2", "Option 3"], │
│    "suggestions": ["Suggestion 1", "Suggestion 2", ...]     │
│  }                                                            │
└─────────────────────────────────────────────────────────────┘
    │
    ▼
Frontend displays rejection + alternatives
```

### Stage 2: Advisor (Environment Blueprint)

```
Validated Policy
    │
    │ "Increase RON95 to RM3.35/litre"
    ▼
┌─────────────────────────────────────────────────────────────┐
│  Gatekeeper (if feasible)                                    │
│  - Generates Environment Blueprint                           │
│  - 8 Universal Knobs (0.0-1.0 initial values)               │
│  - 3-5 Dynamic Sublayers (concrete physics)                 │
└─────────────────────────────────────────────────────────────┘
    │
    │ Contract Pre-B (extended)
    ▼
┌─────────────────────────────────────────────────────────────┐
│  Response: EnvironmentBlueprint                              │
│  {                                                            │
│    "policy_summary": "RON95 price hike...",                 │
│    "universal_knobs": {                                      │
│      "cost_of_living": 0.85,                                │
│      "direct_assistance": 0.20,                             │
│      ...                                                     │
│    },                                                        │
│    "dynamic_sublayers": [                                   │
│      {                                                       │
│        "name": "RON95_Price",                               │
│        "parent_knob": "cost_of_living",                     │
│        "impact_type": "expense",                            │
│        "baseline_value": 2.05,                              │
│        "policy_value": 3.35,                                │
│        "unit": "RM/litre"                                   │
│      },                                                      │
│      ...                                                     │
│    ]                                                         │
│  }                                                            │
└─────────────────────────────────────────────────────────────┘
    │
    ▼
Frontend displays 8 sliders + 5 sublayer cards
```

### Stage 3: Dashboard (Live Simulation)

```
User clicks "Run Simulation"
    │
    │ POST /simulate
    │ Contract A: SimulateRequest
    ▼
┌─────────────────────────────────────────────────────────────┐
│  Backend: simulation_flow()                                  │
│  1. Create fresh Orchestrator instance                       │
│  2. Load 50 agent profiles (agents_master.json)             │
│  3. Initialize physics engine (8 knobs)                      │
│  4. Start tick loop (4-12 ticks)                            │
└─────────────────────────────────────────────────────────────┘
    │
    │ For each tick:
    ▼
┌─────────────────────────────────────────────────────────────┐
│  Tick Loop (Parallel Agent Execution)                        │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Agent 1-17 (B40)  →  Groq Key 1                    │   │
│  │  Agent 18-34 (M40) →  Groq Key 2                    │   │
│  │  Agent 35-50 (T20) →  Groq Key 3                    │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                               │
│  For each agent:                                             │
│  1. Generate observation (world state + RAG context)         │
│  2. Call Groq API (Llama-3.3-70b)                           │
│  3. Parse agent decision (action, sentiment, monologue)      │
│  4. Compute RL reward                                        │
│  5. Update agent state                                       │
│                                                               │
│  After all agents:                                           │
│  6. Aggregate macro metrics                                  │
│  7. Detect anomalies (breaking points)                       │
│  8. Update global state (8 knobs)                           │
│  9. Push SSE event to frontend                              │
└─────────────────────────────────────────────────────────────┘
    │
    │ SSE Stream (per tick)
    ▼
┌─────────────────────────────────────────────────────────────┐
│  event: tick                                                 │
│  data: {                                                     │
│    "tick_id": 1,                                            │
│    "average_sentiment": -0.23,                              │
│    "reward_stability_score": 65.4,                          │
│    "agent_actions": [                                       │
│      {                                                       │
│        "agent_id": "AGT-001",                               │
│        "action": "Cut non-essential spending",              │
│        "sentiment_score": -0.45,                            │
│        "internal_monologue": "I can't afford...",           │
│        "is_breaking_point": false,                          │
│        "reward_score": -0.23                                │
│      },                                                      │
│      ...                                                     │
│    ]                                                         │
│  }                                                           │
└─────────────────────────────────────────────────────────────┘
    │
    ▼
Frontend updates dashboard in real-time
```

### Stage 4: Verdict (AI Recommendation)

```
Simulation completes
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│  Backend: generate_summary()                                 │
│  1. Analyze full timeline (all ticks)                        │
│  2. Compute final Reward Stability Score                     │
│  3. Extract top 5 critical agent monologues                  │
│  4. Call Groq API for Chief Economist summary                │
│  5. Generate AI policy recommendation                        │
└─────────────────────────────────────────────────────────────┘
    │
    │ event: summary
    ▼
┌─────────────────────────────────────────────────────────────┐
│  Chief Economist Summary                                     │
│  "The policy causes a 15% drop in B40 disposable income,    │
│   triggering a recession spiral. Recommend adding a RM100   │
│   monthly transport voucher for B40 households via PADU."   │
└─────────────────────────────────────────────────────────────┘
    │
    │ event: complete
    ▼
┌─────────────────────────────────────────────────────────────┐
│  Contract E: SimulateResponse                                │
│  {                                                            │
│    "simulation_metadata": {...},                            │
│    "macro_summary": {                                        │
│      "overall_sentiment_shift": -0.45,                      │
│      "inequality_delta": 0.12                               │
│    },                                                        │
│    "timeline": [...],                                        │
│    "anomalies": [...],                                       │
│    "ai_policy_recommendation": "..."                        │
│  }                                                            │
└─────────────────────────────────────────────────────────────┘
    │
    ▼
Frontend displays final verdict + export report
```

---

## 🔑 Key Innovation: 3-Key Load Balancing

### The Problem
```
Traditional Approach (Single API Key):
┌──────────┐
│ Agent 1  │ ─┐
│ Agent 2  │ ─┤
│ Agent 3  │ ─┤
│   ...    │ ─┼─► Single Groq API Key ─► Rate Limit Hit!
│ Agent 48 │ ─┤
│ Agent 49 │ ─┤
│ Agent 50 │ ─┘
└──────────┘

Result: Simulation takes 5+ minutes (sequential execution)
```

### Our Solution
```
PolicyIQ Approach (3-Key Round-Robin):
┌──────────────┐
│ Agent 1-17   │ ─► Groq Key 1 (B40 demographic)
│ (B40)        │
└──────────────┘

┌──────────────┐
│ Agent 18-34  │ ─► Groq Key 2 (M40 demographic)
│ (M40)        │
└──────────────┘

┌──────────────┐
│ Agent 35-50  │ ─► Groq Key 3 (T20 demographic)
│ (T20)        │
└──────────────┘

Result: All 50 agents execute in parallel, <5 seconds per tick
```

### Implementation
```python
# backend/ai_engine/key_manager.py
class KeyManager:
    def __init__(self):
        self.keys = [
            os.getenv("GROQ_API_KEY_1"),
            os.getenv("GROQ_API_KEY_2"),
            os.getenv("GROQ_API_KEY_3"),
        ]
        self.current_index = 0
    
    def get_next_key(self) -> str:
        """Round-robin key rotation"""
        key = self.keys[self.current_index]
        self.current_index = (self.current_index + 1) % len(self.keys)
        return key

# backend/ai_engine/orchestrator.py
class Orchestrator:
    semaphore = asyncio.Semaphore(3)  # Match key count
    
    async def _execute_agent(self, agent):
        async with self.semaphore:  # Limit to 3 concurrent calls
            groq_client = self._get_groq_client()  # Gets next key
            response = await groq_client.chat.completions.create(...)
```

---

## 🧠 MARL Architecture

### Multi-Agent Reinforcement Learning Loop

```
┌─────────────────────────────────────────────────────────────┐
│                    MARL Simulation Loop                      │
└─────────────────────────────────────────────────────────────┘

Tick 0 (Initial State):
┌──────────────────────────────────────────────────────────────┐
│  Global State (8 Universal Knobs)                            │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ cost_of_living:      0.85  (high pressure)             │ │
│  │ direct_assistance:   0.20  (low support)               │ │
│  │ taxation_and_revenue: 0.50  (moderate)                 │ │
│  │ labor_and_wages:     0.60  (stable)                    │ │
│  │ healthcare_access:   0.55  (moderate)                  │ │
│  │ education_quality:   0.50  (moderate)                  │ │
│  │ infrastructure:      0.45  (below average)             │ │
│  │ market_stability:    0.40  (low confidence)            │ │
│  └────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
    │
    │ Each agent observes global state + personal state
    ▼
┌──────────────────────────────────────────────────────────────┐
│  Agent Observation (Contract C)                              │
│  {                                                            │
│    "tick_number": 1,                                         │
│    "agent_profile": {                                        │
│      "agent_id": "AGT-001",                                  │
│      "demographic": "B40",                                   │
│      "monthly_income_rm": 3500,                              │
│      "disposable_buffer_rm": 450,                            │
│      "sensitivity_matrix": {...}                             │
│    },                                                         │
│    "rag_context": "DOSM data: B40 petrol spending...",      │
│    "world_update": "RON95 price increased to RM3.35..."     │
│  }                                                            │
└──────────────────────────────────────────────────────────────┘
    │
    │ Agent decides action based on observation
    ▼
┌──────────────────────────────────────────────────────────────┐
│  Agent Decision (Contract D)                                 │
│  {                                                            │
│    "agent_id": "AGT-001",                                    │
│    "action": "Cut non-essential spending by 15%",            │
│    "sentiment_score": -0.45,                                 │
│    "financial_health_change": -120.50,                       │
│    "internal_monologue": "I can't afford my daughter's...",  │
│    "is_breaking_point": false                                │
│  }                                                            │
└──────────────────────────────────────────────────────────────┘
    │
    │ Compute RL reward
    ▼
┌──────────────────────────────────────────────────────────────┐
│  Reward Function                                             │
│  Rt = 0.5 × ΔDisposable Buffer                              │
│     + 0.3 × ΔSentiment                                       │
│     - 0.2 × DTI Stress                                       │
│                                                               │
│  For AGT-001:                                                │
│  Rt = 0.5 × (-120.50/3500)                                  │
│     + 0.3 × (-0.45 - 0.0)                                   │
│     - 0.2 × 0.35                                            │
│  Rt = -0.017 - 0.135 - 0.070 = -0.222                       │
│                                                               │
│  Negative reward → Policy is hurting this agent             │
└──────────────────────────────────────────────────────────────┘
    │
    │ Aggregate all 50 agent rewards
    ▼
┌──────────────────────────────────────────────────────────────┐
│  Macro Aggregation                                           │
│  - Average reward per demographic (B40, M40, T20)            │
│  - Overall sentiment shift                                   │
│  - Inequality delta (Gini coefficient)                       │
│  - Breaking point count                                      │
│  - Reward Stability Score (0-100)                            │
└──────────────────────────────────────────────────────────────┘
    │
    │ Update global state based on agent actions
    ▼
Tick 1 (Updated State):
┌──────────────────────────────────────────────────────────────┐
│  Global State (8 Universal Knobs) — UPDATED                  │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ cost_of_living:      0.90  ↑ (agents cutting spending) │ │
│  │ direct_assistance:   0.20  → (no change)               │ │
│  │ market_stability:    0.35  ↓ (consumer confidence down)│ │
│  │ ...                                                     │ │
│  └────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
    │
    │ Repeat for next tick (emergent cascading effects)
    ▼
```

---

## 📊 Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    PolicyIQ Data Flow                        │
└─────────────────────────────────────────────────────────────┘

User Input
    │
    ▼
┌─────────────┐
│  Frontend   │
│  (Flutter)  │
└─────────────┘
    │
    │ HTTP POST /validate-policy
    │ Contract Pre-A: {"raw_policy_text": "..."}
    ▼
┌─────────────────────────────────────────────────────────────┐
│  Backend (FastAPI)                                           │
│  ┌───────────────────────────────────────────────────────┐ │
│  │  main.py                                               │ │
│  │  - CORS middleware                                     │ │
│  │  - Route handlers                                      │ │
│  │  - SSE streaming                                       │ │
│  └───────────────────────────────────────────────────────┘ │
│                          │                                   │
│                          ▼                                   │
│  ┌───────────────────────────────────────────────────────┐ │
│  │  orchestrator.py                                       │ │
│  │  - validate_policy()                                   │ │
│  │  - run_simulation()                                    │ │
│  │  - generate_summary()                                  │ │
│  └───────────────────────────────────────────────────────┘ │
│                          │                                   │
│                          ▼                                   │
│  ┌───────────────────────────────────────────────────────┐ │
│  │  key_manager.py                                        │ │
│  │  - Round-robin key rotation                            │ │
│  │  - 3-key load balancing                                │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
    │
    │ Groq API (3 keys)
    ▼
┌─────────────────────────────────────────────────────────────┐
│  Llama-3.3-70b Inference                                     │
│  - Gatekeeper validation                                     │
│  - Agent decision generation                                 │
│  - Chief Economist summary                                   │
└─────────────────────────────────────────────────────────────┘
    │
    │ RAG Context
    ▼
┌─────────────────────────────────────────────────────────────┐
│  DOSM Data (backend/data/*.jsonl)                            │
│  - cpi_2d_state_cleaned.jsonl                                │
│  - hies_state_cleaned.jsonl                                  │
│  - interest_rates_cleaned.jsonl                              │
│  - ridership_headline_cleaned.jsonl                          │
└─────────────────────────────────────────────────────────────┘
    │
    │ Grounded context
    ▼
┌─────────────────────────────────────────────────────────────┐
│  Agent Decision (Contract D)                                 │
│  - Action                                                     │
│  - Sentiment                                                  │
│  - Financial health change                                   │
│  - Internal monologue                                        │
└─────────────────────────────────────────────────────────────┘
    │
    │ SSE Stream
    ▼
┌─────────────┐
│  Frontend   │
│  Dashboard  │
│  - Real-time updates                                         │
│  - Charts & visualizations                                   │
│  - Anomaly alerts                                            │
└─────────────┘
```

---

## 🔒 Security Architecture

### Hackathon Configuration (Current)
```
┌─────────────┐         ┌─────────────┐
│   Flutter   │         │   FastAPI   │
│   (Public)  │ ◄─────► │  (Public)   │
└─────────────┘         └─────────────┘
                              │
                              │ Environment Variables
                              ▼
                        ┌─────────────┐
                        │  Groq Keys  │
                        │  (Secret)   │
                        └─────────────┘

- CORS: allow_origins=["*"]
- Authentication: --allow-unauthenticated
- API Keys: Set via Cloud Run environment variables
```

### Production Configuration (Post-Hackathon)
```
┌─────────────┐         ┌─────────────┐
│   Flutter   │         │   FastAPI   │
│  (Specific  │ ◄─────► │  (Auth      │
│   Domain)   │         │   Required) │
└─────────────┘         └─────────────┘
                              │
                              │ Secret Manager
                              ▼
                        ┌─────────────┐
                        │  GCP Secret │
                        │  Manager    │
                        └─────────────┘

- CORS: allow_origins=["https://your-domain.com"]
- Authentication: API key or OAuth
- Rate Limiting: 10 requests/minute per IP
- Secrets: Google Cloud Secret Manager
```

---

## 📈 Performance Characteristics

### Latency Breakdown
```
Total Simulation Time (50 agents, 4 ticks): ~18 seconds

┌─────────────────────────────────────────────────────────────┐
│  Tick 1: 4.5s                                                │
│  ├─ Agent execution (parallel): 3.8s                         │
│  ├─ RAG context retrieval: 0.3s                              │
│  ├─ Aggregation & physics: 0.2s                              │
│  └─ SSE push: 0.2s                                           │
│                                                               │
│  Tick 2: 4.2s (cache warm)                                   │
│  Tick 3: 4.3s                                                │
│  Tick 4: 4.5s                                                │
│                                                               │
│  Summary generation: 0.5s                                    │
└─────────────────────────────────────────────────────────────┘
```

### Scalability
```
Current: 50 agents, 3 keys, 4 ticks = 18s
With 6 keys: 50 agents, 6 keys, 4 ticks = 10s
With 10 keys: 100 agents, 10 keys, 4 ticks = 12s
```

---

## 🎯 Deployment Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  Google Cloud Run                            │
│                                                               │
│  ┌───────────────────────────────────────────────────────┐ │
│  │  policyiq-backend                                      │ │
│  │  Region: asia-southeast1 (Singapore/Malaysia)          │ │
│  │  Memory: 2 GB                                          │ │
│  │  CPU: 2 vCPUs                                          │ │
│  │  Timeout: 300s                                         │ │
│  │  Concurrency: 80 requests per instance                │ │
│  │  Auto-scaling: 0-10 instances                          │ │
│  └───────────────────────────────────────────────────────┘ │
│                          │                                   │
│                          │ Environment Variables             │
│                          ▼                                   │
│  ┌───────────────────────────────────────────────────────┐ │
│  │  GROQ_API_KEY_1=gsk_...                               │ │
│  │  GROQ_API_KEY_2=gsk_...                               │ │
│  │  GROQ_API_KEY_3=gsk_...                               │ │
│  │  GROQ_MODEL=llama-3.3-70b-versatile                   │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
    │
    │ HTTPS
    ▼
┌─────────────────────────────────────────────────────────────┐
│  Public URL                                                  │
│  https://policyiq-backend-<hash>-as.a.run.app               │
│  - /health                                                   │
│  - /docs                                                     │
│  - /validate-policy                                          │
│  - /simulate                                                 │
│  - /export-report/{simulation_id}                           │
└─────────────────────────────────────────────────────────────┘
```

---

**This architecture enables PolicyIQ to simulate 50 Digital Malaysians in real-time, providing government decision-makers with data-driven policy insights before deployment.**

**Built with ❤️ for Malaysia's 34 million citizens**
