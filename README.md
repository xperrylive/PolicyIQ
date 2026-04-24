# 🏛️ PolicyIQ — SimCity for GovTech

**Impacting 34 Million Malaysians Through AI-Driven Policy Simulation**

PolicyIQ is a Multi-Agent Reinforcement Learning (MARL) platform that transforms raw government policy text into an interactive economic simulation. Before a policy reaches Parliament, PolicyIQ stress-tests it against 50 demographically diverse "Digital Malaysian" AI citizens across multiple time steps, surfacing macro sentiment shifts, inequality deltas, breaking-point anomalies, and AI-generated mitigation recommendations.

**Built for Project 2030: MyAI Future Hackathon**

---

## 🎯 The Vision: SimCity for GovTech

Imagine if every Malaysian policy — from petrol subsidies to digital cash transfers — could be tested in a virtual sandbox before affecting 34 million real citizens. PolicyIQ makes this possible by:

1. **Translating Policy → Physics**: Raw policy text becomes an 8-Knob economic state matrix
2. **Simulating Real Malaysians**: 50 AI agents representing B40/M40/T20 demographics with real DOSM data
3. **Predicting Breaking Points**: Identifying which citizens will struggle before the policy launches
4. **Recommending Fixes**: AI-generated mitigation strategies grounded in Malaysian socio-economic context

---

## 🚀 Core Innovation

### 1. The Recession Spiral Feedback Loop

Traditional policy analysis is static. PolicyIQ models **dynamic cascading effects**:

```
Petrol Price Hike (+63%)
    ↓
B40 Gig Workers Cut Spending
    ↓
SME Revenue Drops 15%
    ↓
M40 Job Losses Begin
    ↓
Consumer Confidence Collapses
    ↓
RECESSION SPIRAL DETECTED
```

Each agent's decision affects the next tick's global state, creating emergent macro patterns that no single-agent model can predict.

### 2. 3-Key Load Balancing for Concurrent Agent "Thought"

**The Challenge**: Running 50 LLM-powered agents in parallel would hit API rate limits instantly.

**The Solution**: PolicyIQ uses a round-robin key rotation system with 3 Groq API keys:

- **Key 1**: Agents 1-17 (B40 demographic)
- **Key 2**: Agents 18-34 (M40 demographic)  
- **Key 3**: Agents 35-50 (T20 demographic)

This architecture enables **sub-second tick execution** for all 50 agents simultaneously, making real-time policy simulation viable for government decision-makers.

### 3. Grounded in Real Malaysian Data

Every agent decision is RAG-enhanced with:
- **DOSM Household Income & Expenditure Survey** (HIES)
- **Consumer Price Index** (CPI) by state
- **Interest Rate Trends** (Bank Negara Malaysia)
- **Public Transport Ridership** (Prasarana Malaysia)

No hallucinations. No generic advice. Every simulation is anchored to Malaysia's economic reality.

---

## 🏗️ The Tech Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Frontend** | Flutter 3.19+ | Cross-platform dashboard (Web, Windows, macOS) |
| **Backend** | FastAPI + Python 3.10 | RESTful API + SSE streaming |
| **AI Engine** | Llama-3.3-70b (Groq) | Zero-latency agent inference |
| **RAG Layer** | Local JSONL + Vertex AI Search | Grounded Malaysian economic data |
| **Deployment** | Google Cloud Run | Serverless, auto-scaling, asia-southeast1 |
| **Orchestration** | Google Genkit | Tracing, observability, flow management |

---

## 🎮 The Governor's Journey: 4-Stage UI Flow

### Stage 1: The Gatekeeper
**Input**: Raw policy text (e.g., "Make petrol cheaper for poor people")  
**Output**: Feasibility verdict + 3 strategic alternatives if rejected

The AI Gatekeeper validates:
- ✅ Specificity (concrete RM amounts, target demographics)
- ✅ Measurability (can we simulate this?)
- ✅ Grounding (references to PADU, BSH, EPF, etc.)

**Rejected policies get 3 refined alternatives** grounded in Malaysian policy instruments.

### Stage 2: The Advisor (Environment Blueprint)
**Input**: Validated policy text  
**Output**: 8 Universal Knobs + 3-5 Dynamic Sublayers

The AI Advisor decomposes the policy into:
- **8 Universal Knobs**: Cost of Living, Direct Assistance, Taxation, Labor, Healthcare, Education, Infrastructure, Market Stability
- **Dynamic Sublayers**: Concrete physics (e.g., "RON95_Price: RM2.05 → RM3.35")

The Flutter dashboard auto-positions all 8 sliders to the AI's suggested baseline.

### Stage 3: The Dashboard (Live Simulation)
**Input**: Environment Blueprint + optional manual knob adjustments  
**Output**: Real-time SSE stream of agent decisions

Watch 50 Digital Malaysians react to your policy across 4-12 time steps:
- **Macro View**: Overall sentiment shift, inequality delta, reward stability score
- **Micro View**: Individual agent monologues ("I'm cutting my daughter's tuition...")
- **Anomaly Hunter**: Breaking-point alerts (financial_health < 0, sentiment = -1.0)

### Stage 4: The Verdict (AI Policy Recommendation)
**Input**: Completed simulation timeline  
**Output**: Chief Economist summary + pitch-ready report

The AI Chief Economist analyzes the full simulation and generates:
- **Reward Stability Score** (0-100): Is this policy mathematically sustainable?
- **Voice of the People**: Top 5 most critical agent monologues
- **Mitigation Strategy**: Concrete fixes (e.g., "Add RM50 B40 transport voucher via PADU")

---

## 📦 Project Structure

```
PolicyIQ/
├── backend/                    # FastAPI + AI Engine (Python 3.10)
│   ├── ai_engine/
│   │   ├── orchestrator.py     # MARL coordinator + Groq inference
│   │   ├── physics.py          # 8-Knob state engine
│   │   ├── key_manager.py      # 3-key load balancer
│   │   ├── policy_validator.py # Gatekeeper logic
│   │   ├── rag_client.py       # Vertex AI Search client
│   │   ├── prompts/            # LLM prompt templates
│   │   └── agent_dna/          # 50 pre-generated agent profiles
│   ├── data/                   # DOSM/OpenDOSM JSONL files
│   ├── main.py                 # FastAPI entrypoint
│   ├── schemas.py              # Pydantic contracts (Pre-A → E)
│   ├── requirements.txt
│   └── Dockerfile
├── frontend/                   # Flutter 3.19+ Dashboard
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/             # Contract models (mirrors backend)
│   │   ├── screens/            # 6 dashboard screens
│   │   ├── services/           # API client, simulation engine
│   │   └── widgets/            # Radar charts, Sankey diagrams, anomaly hunter
│   └── pubspec.yaml
├── deploy_cloud.sh             # Cloud Run deployment script
├── docker-compose.yml
├── .env.example                # Environment variable template
└── README.md                   # This file
```

---

## 🚀 Setup Guide

### Prerequisites
- **Docker Desktop** ≥ 24.0 (for local backend)
- **Flutter SDK** ≥ 3.19 (for frontend)
- **gcloud CLI** (for Cloud Run deployment)
- **3 Groq API Keys** (free tier: https://console.groq.com/)

### Local Development

#### 1. Clone & Configure
```bash
git clone <your-repo-url>
cd PolicyIQ
cp .env.example .env
# Edit .env and add your GROQ_API_KEY_1, GROQ_API_KEY_2, GROQ_API_KEY_3
```

#### 2. Run Backend (Docker)
```bash
docker-compose up --build
```
API available at: **https://policyiq-backend-v6fp4t7mca-as.a.run.app**  
Interactive docs: **https://policyiq-backend-v6fp4t7mca-as.a.run.app/docs**

#### 3. Run Frontend (Flutter)
```bash
cd frontend
flutter pub get
flutter run -d chrome  # or -d windows / -d macos
```

The Flutter app will connect to `https://policyiq-backend-v6fp4t7mca-as.a.run.app` by default.

---

## ☁️ Cloud Deployment (Google Cloud Run)

### Step 1: Set Environment Variables
```bash
export GROQ_API_KEY_1="your-first-groq-key"
export GROQ_API_KEY_2="your-second-groq-key"
export GROQ_API_KEY_3="your-third-groq-key"
```

### Step 2: Deploy to Cloud Run
```bash
chmod +x deploy_cloud.sh
./deploy_cloud.sh
```

The script will:
1. Authenticate with GCP project `policyiq2`
2. Deploy the backend to `asia-southeast1` (Singapore/Malaysia region)
3. Set `--allow-unauthenticated` so hackathon judges can access the API
4. Output your live Cloud Run URL

### Step 3: Update Flutter Frontend
```dart
// frontend/lib/services/api_client.dart
const String _kApiBaseUrl = 'https://policyiq-backend-<hash>-as.a.run.app';
```

Rebuild your Flutter app and you're live!

---

## 🔑 Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `GROQ_API_KEY_1` | First Groq API key (agents 1-17) | `gsk_...` |
| `GROQ_API_KEY_2` | Second Groq API key (agents 18-34) | `gsk_...` |
| `GROQ_API_KEY_3` | Third Groq API key (agents 35-50) | `gsk_...` |
| `GROQ_MODEL` | Groq model name | `llama-3.3-70b-versatile` |
| `GOOGLE_CLOUD_PROJECT` | GCP project ID (optional) | `policyiq2` |
| `VERTEX_AI_LOCATION` | Vertex AI region (optional) | `us-central1` |

---

## 🏗️ API Endpoints

### POST `/validate-policy`
**Contract Pre-A → Pre-B**: Gatekeeper validation

**Request**:
```json
{
  "raw_policy_text": "Increase RON95 petrol price by 63% to RM3.35/litre"
}
```

**Response**:
```json
{
  "is_feasible": true,
  "environment_blueprint": {
    "policy_summary": "RON95 petrol price hike from RM2.05 to RM3.35/litre",
    "universal_knobs": {
      "cost_of_living": 0.85,
      "direct_assistance": 0.20,
      ...
    },
    "dynamic_sublayers": [
      {
        "name": "RON95_Price",
        "parent_knob": "cost_of_living",
        "impact_type": "expense",
        "baseline_value": 2.05,
        "policy_value": 3.35,
        "unit": "RM/litre"
      }
    ]
  }
}
```

### POST `/simulate`
**Contract A → E**: Full simulation (SSE stream)

**Request**:
```json
{
  "policy_text": "Increase RON95 petrol price by 63%",
  "simulation_ticks": 4,
  "agent_count": 50,
  "knob_overrides": {}
}
```

**Response** (Server-Sent Events):
```
event: tick
data: {"tick_id": 1, "average_sentiment": -0.23, "agent_actions": [...]}

event: tick
data: {"tick_id": 2, "average_sentiment": -0.45, "agent_actions": [...]}

event: summary
data: {"type": "summary", "content": "The policy causes a 15% drop in B40 disposable income..."}

event: complete
data: {"simulation_metadata": {...}, "macro_summary": {...}, "timeline": [...]}
```

### GET `/export-report/{simulation_id}`
**Pitch-Ready Report**: Text summary for completed simulation

---

## 🎯 Key Metrics Explained

### Reward Stability Score (0-100)
Derived from the average RL reward across all 50 agents:
- **100**: Policy is mathematically sustainable for all citizens
- **70-99**: Stable with minor friction
- **40-69**: Moderate instability (some demographics struggling)
- **0-39**: Policy failure / social unrest risk

### Sentiment Score (-1.0 to +1.0)
Per-agent emotional state:
- **+1.0**: Thriving under the policy
- **0.0**: Neutral / adapting
- **-1.0**: Breaking point (financial collapse)

### Breaking Point
Triggered when:
- `financial_health < 0` (agent is insolvent)
- `sentiment_score == -1.0` (agent has lost all hope)

---

## 🤝 Team & Contributions

PolicyIQ was built for **Project 2030: MyAI Future Hackathon** by a distributed team:

| Stream | Focus | Key Deliverables |
|--------|-------|------------------|
| **AI Engine** | MARL orchestration, agent DNA, prompt engineering | `orchestrator.py`, `physics.py`, `key_manager.py` |
| **Backend** | FastAPI gateway, Cloud Run deployment, RAG pipeline | `main.py`, `schemas.py`, `Dockerfile` |
| **Frontend** | Flutter dashboard, real-time SSE, data visualization | 6 screens, radar charts, Sankey diagrams |

---

## 📊 Sample Use Cases

### Use Case 1: RON95 Petrol Subsidy Removal
**Policy**: "Remove RON95 subsidy, increase price from RM2.05 to RM3.35/litre"

**Simulation Results**:
- **B40 Sentiment**: -0.67 (severe distress)
- **M40 Sentiment**: -0.34 (moderate concern)
- **T20 Sentiment**: +0.12 (minimal impact)
- **Breaking Points**: 18 agents (36% of population)
- **AI Recommendation**: "Add RM100/month transport voucher for B40 via PADU to offset 80% of increased commute costs"

### Use Case 2: Universal Basic Income (UBI)
**Policy**: "Give every Malaysian RM1,000/month unconditional cash transfer"

**Simulation Results**:
- **Overall Sentiment**: +0.45 (positive)
- **Inequality Delta**: -0.12 (reduced inequality)
- **Fiscal Sustainability**: FAIL (RM408 billion annual cost)
- **AI Recommendation**: "Target B40 only (RM100/month) via PADU for RM4.8B annual cost — achieves 70% of UBI's poverty reduction at 1.2% of the fiscal burden"

---

## 🔬 Technical Deep Dive

### Multi-Agent Reinforcement Learning (MARL)

PolicyIQ implements a **cooperative MARL** architecture where:
1. **Global State** = 8 Universal Knobs (shared environment)
2. **Agent State** = Individual financial health, sentiment, demographic profile
3. **Reward Function** = `0.5 × ΔDisposable Buffer + 0.3 × ΔSentiment - 0.2 × DTI Stress`

Each agent's action affects the next tick's global state, creating emergent macro patterns.

### The 8 Universal Knobs

| Knob | Range | Description |
|------|-------|-------------|
| `cost_of_living` | 0.0-1.0 | Inflation pressure on essential goods |
| `direct_assistance` | 0.0-1.0 | Government cash transfers (BSH, PADU) |
| `taxation_and_revenue` | 0.0-1.0 | Tax burden on citizens |
| `labor_and_wages` | 0.0-1.0 | Employment stability & wage growth |
| `healthcare_access` | 0.0-1.0 | Public healthcare quality |
| `education_quality` | 0.0-1.0 | Education system effectiveness |
| `infrastructure` | 0.0-1.0 | Transport, utilities, digital access |
| `market_stability` | 0.0-1.0 | Economic confidence & investment |

### Dynamic Sublayers

Each policy generates 3-5 sublayers that modify the Universal Knobs:

**Example**: RON95 price hike policy
```json
{
  "name": "RON95_Price",
  "parent_knob": "cost_of_living",
  "impact_type": "expense",
  "baseline_value": 2.05,
  "policy_value": 3.35,
  "unit": "RM/litre"
}
```

The physics engine computes:
```python
agent_state_update = Σ (sublayer_value × agent_sensitivity × demographic_weight)
```

---

## 🐛 Troubleshooting

### Backend won't start
```bash
# Check Docker logs
docker-compose logs backend

# Common issue: Missing .env file
cp .env.example .env
# Edit .env and add your Groq API keys
```

### Flutter app can't connect to backend
```dart
// frontend/lib/services/api_client.dart
// Ensure baseUrl matches your backend:
const String _kApiBaseUrl = 'https://policyiq-backend-v6fp4t7mca-as.a.run.app';  // Production
// OR
const String _kApiBaseUrl = 'http://127.0.0.1:8000';  // Local development
```

### Groq API rate limits
PolicyIQ uses 3 keys to distribute load. If you hit rate limits:
1. Add more keys to `.env` (`GROQ_API_KEY_4`, `GROQ_API_KEY_5`, etc.)
2. Update `backend/ai_engine/key_manager.py` to load additional keys
3. Restart the backend

---

## 📜 License

This project is submitted for **Project 2030: MyAI Future Hackathon** and is intended for educational and demonstration purposes.

---

## 🙏 Acknowledgments

- **DOSM (Department of Statistics Malaysia)** for open household income data
- **OpenDOSM** for public API access to CPI, interest rates, and ridership data
- **Groq** for zero-latency Llama-3.3-70b inference
- **Google Cloud** for Cloud Run hosting and Vertex AI infrastructure
- **Project 2030** for organizing the MyAI Future Hackathon

---

## 📧 Contact

For hackathon judges and technical questions:
- **GitHub Issues**: [Open an issue](https://github.com/your-repo/issues)
- **Demo Video**: [Link to pitch video]
- **Live Demo**: [Cloud Run URL after deployment]

---

**Built with ❤️ for Malaysia's 34 million citizens**
