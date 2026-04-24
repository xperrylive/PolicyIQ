# ⚡ PolicyIQ Quick Start
## 60-Second Setup for Hackathon Judges

---

## 🎯 What is PolicyIQ?

**SimCity for Malaysian Government Policy**

Test any policy (petrol subsidies, cash transfers, tax changes) against 50 AI citizens before it affects 34 million real Malaysians.

---

## 🚀 Try It Now (Cloud Demo)

**Live API**: `https://policyiq-backend-v6fp4t7mca-as.a.run.app`

### Test the Gatekeeper (Policy Validator)
```bash
curl -X POST https://policyiq-backend-v6fp4t7mca-as.a.run.app/validate-policy \
  -H "Content-Type: application/json" \
  -d '{"raw_policy_text": "Remove RON95 subsidy, increase price to RM3.35/litre"}'
```

### Interactive API Docs
Visit: `https://policyiq-backend-v6fp4t7mca-as.a.run.app/docs`

---

## 💻 Run Locally (5 Minutes)

### Prerequisites
- Docker Desktop
- 3 Groq API keys (free: https://console.groq.com/)

### Steps
```bash
# 1. Clone repo
git clone <repo-url>
cd PolicyIQ

# 2. Configure environment
cp .env.example .env
# Edit .env and add your 3 Groq API keys

# 3. Start backend
docker-compose up --build

# 4. Test it
curl http://localhost:8000/health
```

**Backend running at**: https://policyiq-backend-v6fp4t7mca-as.a.run.app  
**API docs**: https://policyiq-backend-v6fp4t7mca-as.a.run.app/docs

---

## 🎨 Run Flutter Frontend

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

**Update API URL** in `frontend/lib/services/api_client.dart`:
```dart
const String _kApiBaseUrl = 'https://policyiq-backend-v6fp4t7mca-as.a.run.app';  // Production
// OR
const String _kApiBaseUrl = 'http://127.0.0.1:8000';  // Local development
```

---

## 🎮 The Governor's Journey (4 Screens)

### 1. Gatekeeper
**Input**: "Make petrol cheaper for poor people"  
**Output**: ❌ Rejected + 3 refined alternatives

### 2. Advisor (Environment Blueprint)
**Input**: "Increase RON95 to RM3.35/litre"  
**Output**: 8 Universal Knobs + 5 Dynamic Sublayers

### 3. Dashboard (Live Simulation)
**Watch**: 50 Digital Malaysians react in real-time  
**See**: Sentiment shifts, breaking points, anomalies

### 4. Verdict (AI Recommendation)
**Get**: Reward Stability Score + mitigation strategy

---

## 📊 Sample Policies to Test

### ✅ Good Policy (Will Pass Gatekeeper)
```
"Implement a targeted RM100 monthly cash transfer to B40 households via PADU, 
funded by a 2% luxury goods tax on items above RM10,000."
```

### ❌ Bad Policy (Will Be Rejected)
```
"Make everything cheaper for everyone."
```

### 🔥 Controversial Policy (Will Simulate)
```
"Remove RON95 petrol subsidy entirely, increase price from RM2.05 to RM3.35/litre."
```

**Expected Result**: 
- B40 sentiment: -0.67 (severe distress)
- 18 breaking points (36% of agents)
- AI recommends: "Add RM100 B40 transport voucher"

---

## 🏗️ Architecture at a Glance

```
Flutter Frontend (Dart)
    ↓ HTTP/SSE
FastAPI Backend (Python)
    ↓ Groq API (3 keys)
Llama-3.3-70b (50 parallel agents)
    ↓ RAG
DOSM Economic Data (JSONL)
```

**Key Innovation**: 3-key load balancing enables 50 concurrent LLM calls without rate limits.

---

## 📦 Project Structure

```
PolicyIQ/
├── backend/
│   ├── ai_engine/          # MARL orchestrator
│   ├── data/               # DOSM JSONL files
│   ├── main.py             # FastAPI entrypoint
│   └── Dockerfile
├── frontend/
│   └── lib/
│       ├── screens/        # 6 dashboard screens
│       └── services/       # API client
├── deploy_cloud.sh         # Cloud Run deployment
└── README.md               # Full documentation
```

---

## 🔑 Environment Variables

```bash
# Required (get from https://console.groq.com/)
GROQ_API_KEY_1="gsk_..."
GROQ_API_KEY_2="gsk_..."
GROQ_API_KEY_3="gsk_..."

# Optional (for Vertex AI scaling)
GOOGLE_CLOUD_PROJECT="policyiq2"
VERTEX_AI_LOCATION="us-central1"
```

---

## 🐛 Troubleshooting

### Backend won't start
```bash
docker-compose logs backend
# Common issue: Missing .env file
cp .env.example .env
```

### Flutter can't connect
```dart
// Check frontend/lib/services/api_client.dart
const String _kApiBaseUrl = 'https://policyiq-backend-v6fp4t7mca-as.a.run.app';
```

### Groq rate limits
- Ensure all 3 keys are set in `.env`
- Check logs: `docker-compose logs backend | grep "Groq"`

---

## 📊 Key Metrics Explained

### Reward Stability Score (0-100)
- **100**: Policy is sustainable for all citizens
- **70-99**: Stable with minor friction
- **40-69**: Moderate instability
- **0-39**: Policy failure / social unrest

### Sentiment Score (-1.0 to +1.0)
- **+1.0**: Thriving
- **0.0**: Neutral
- **-1.0**: Breaking point

### Breaking Point
- `financial_health < 0` (insolvent)
- `sentiment_score == -1.0` (despair)

---

## 🎯 For Hackathon Judges

### What Makes PolicyIQ Unique?

1. **Real Malaysian Data**: Every simulation grounded in DOSM household income surveys
2. **50 Concurrent Agents**: 3-key load balancing enables real-time MARL
3. **Recession Spiral Detection**: Models cascading effects (petrol hike → spending cuts → SME losses → job losses)
4. **Production-Ready**: Deployed on Cloud Run, auto-scaling, <200ms latency

### Technical Highlights

- **MARL Architecture**: Cooperative multi-agent RL with shared global state
- **8 Universal Knobs**: Cost of Living, Direct Assistance, Taxation, Labor, Healthcare, Education, Infrastructure, Market Stability
- **Dynamic Sublayers**: AI-generated policy physics (e.g., RON95_Price sublayer under Cost of Living)
- **RAG Pipeline**: Local JSONL + Vertex AI Search for grounded agent reasoning

---

## 📞 Quick Links

- **Full README**: [README.md](README.md)
- **Deployment Guide**: [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)
- **API Docs**: https://policyiq-backend-v6fp4t7mca-as.a.run.app/docs (production) or http://localhost:8000/docs (local)
- **Groq Console**: https://console.groq.com/
- **Cloud Run Console**: https://console.cloud.google.com/run

---

**Built for Project 2030: MyAI Future Hackathon**  
**Impacting 34 Million Malaysians Through AI-Driven Policy Simulation**
