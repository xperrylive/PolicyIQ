# 📚 PolicyIQ Documentation Index
## Project 2030: MyAI Future Hackathon

Welcome to PolicyIQ! This index helps you navigate all documentation files.

---

## 🚀 Getting Started (Start Here!)

### For Hackathon Judges
1. **[QUICK_START.md](QUICK_START.md)** — 60-second setup guide
   - Try the live demo
   - Test sample policies
   - Understand key metrics

### For Developers
1. **[README.md](README.md)** — Comprehensive project overview
   - Vision & innovation
   - Tech stack
   - Architecture deep dive
2. **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** — Step-by-step Cloud Run deployment
   - Prerequisites
   - Deployment steps
   - Troubleshooting

---

## 📋 Deployment Resources

### Pre-Deployment
- **[DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md)** — Complete pre-flight checklist
  - Environment setup
  - Code quality checks
  - Testing procedures

### Deployment Scripts
- **[deploy_cloud.sh](deploy_cloud.sh)** — Automated Cloud Run deployment
  - One-command deployment
  - Environment variable configuration
  - Region: asia-southeast1

### Post-Deployment
- **[test_deployment.sh](test_deployment.sh)** — Automated deployment verification
  - Health check
  - API endpoint testing
  - CORS validation

---

## 🏆 Hackathon Submission

### Summary Document
- **[HACKATHON_SUMMARY.md](HACKATHON_SUMMARY.md)** — Complete hackathon submission
  - Problem statement
  - Technical innovation
  - Impact metrics
  - Sample use cases

### Key Highlights
- **Problem**: 34M Malaysians affected by untested policies
- **Solution**: MARL-powered policy simulation
- **Innovation**: 3-key load balancing for 50 concurrent agents
- **Impact**: Prevents RM10B+ in policy reversal costs

---

## 🏗️ Technical Documentation

### Architecture
```
PolicyIQ/
├── backend/                    # FastAPI + AI Engine
│   ├── ai_engine/
│   │   ├── orchestrator.py     # MARL coordinator
│   │   ├── physics.py          # 8-Knob state engine
│   │   ├── key_manager.py      # 3-key load balancer
│   │   └── prompts/            # LLM templates
│   ├── data/                   # DOSM JSONL files
│   ├── main.py                 # FastAPI entrypoint
│   └── Dockerfile
├── frontend/                   # Flutter Dashboard
│   └── lib/
│       ├── screens/            # 6 dashboard screens
│       └── services/           # API client
└── deploy_cloud.sh             # Cloud Run deployment
```

### Key Files
- **backend/main.py** — FastAPI endpoints (validate, simulate, export)
- **backend/schemas.py** — Pydantic contracts (Pre-A → E)
- **backend/ai_engine/orchestrator.py** — MARL orchestration + Groq inference
- **frontend/lib/services/api_client.dart** — HTTP/SSE client

---

## 🎮 User Journey

### The Governor's Journey (4 Stages)

1. **Gatekeeper** (Policy Validator)
   - Input: Raw policy text
   - Output: Feasibility verdict + 3 alternatives

2. **Advisor** (Environment Blueprint)
   - Input: Validated policy
   - Output: 8 Universal Knobs + 3-5 Dynamic Sublayers

3. **Dashboard** (Live Simulation)
   - Input: Environment Blueprint
   - Output: Real-time SSE stream of 50 agent decisions

4. **Verdict** (AI Recommendation)
   - Input: Completed simulation
   - Output: Reward Stability Score + mitigation strategy

---

## 📊 Sample Policies

### ✅ Good Policy (Will Pass Gatekeeper)
```
"Implement a targeted RM100 monthly cash transfer to B40 households via PADU, 
funded by a 2% luxury goods tax on items above RM10,000."
```

### ❌ Bad Policy (Will Be Rejected)
```
"Make everything cheaper for everyone."
```

### 🔥 Controversial Policy (Will Simulate with Warnings)
```
"Remove RON95 petrol subsidy entirely, increase price from RM2.05 to RM3.35/litre."
```

**Expected Result**:
- B40 sentiment: -0.67 (severe distress)
- 18 breaking points (36% of agents)
- AI recommends: "Add RM100 B40 transport voucher"

---

## 🔑 Configuration

### Environment Variables
```bash
# Required (get from https://console.groq.com/)
GROQ_API_KEY_1="gsk_..."
GROQ_API_KEY_2="gsk_..."
GROQ_API_KEY_3="gsk_..."
GROQ_MODEL="llama-3.3-70b-versatile"

# Optional (for Vertex AI scaling)
GOOGLE_CLOUD_PROJECT="policyiq2"
VERTEX_AI_LOCATION="us-central1"
```

### Files
- **[.env.example](.env.example)** — Environment variable template
- **[.env](.env)** — Your local configuration (not committed)

---

## 🧪 Testing

### Local Testing
```bash
# Backend
docker-compose up --build
curl http://localhost:8000/health

# Frontend
cd frontend
flutter run -d chrome
```

### Cloud Testing
```bash
# Automated verification
./test_deployment.sh https://your-cloud-run-url

# Manual testing
curl https://your-cloud-run-url/health
curl https://your-cloud-run-url/docs
```

---

## 🐛 Troubleshooting

### Common Issues

**Backend won't start**
- Check `.env` file exists
- Verify Groq API keys are valid
- Review logs: `docker-compose logs backend`

**Flutter can't connect**
- Verify `_kApiBaseUrl` in `api_client.dart`
- Test `/health` endpoint in browser
- Check CORS configuration

**Groq rate limits**
- Ensure all 3 keys are set
- Check logs for rate limit errors
- Add more keys if needed

### Debug Commands
```bash
# View Cloud Run logs
gcloud run logs read policyiq-backend --region=asia-southeast1

# Check service status
gcloud run services list

# Describe service
gcloud run services describe policyiq-backend --region=asia-southeast1
```

---

## 📞 Quick Links

### Documentation
- [README.md](README.md) — Main project overview
- [QUICK_START.md](QUICK_START.md) — 60-second setup
- [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) — Cloud Run deployment
- [HACKATHON_SUMMARY.md](HACKATHON_SUMMARY.md) — Submission summary

### Live Resources
- **API Docs**: `https://your-cloud-run-url/docs`
- **Health Check**: `https://your-cloud-run-url/health`
- **Groq Console**: https://console.groq.com/
- **Cloud Run Console**: https://console.cloud.google.com/run

### External Resources
- **DOSM**: https://www.dosm.gov.my/
- **OpenDOSM**: https://open.dosm.gov.my/
- **Groq Documentation**: https://console.groq.com/docs
- **Google Cloud Run**: https://cloud.google.com/run/docs

---

## 🎯 Document Purpose Matrix

| Document | Audience | Purpose | Read Time |
|----------|----------|---------|-----------|
| **QUICK_START.md** | Judges, First-time users | Get running in 60 seconds | 2 min |
| **README.md** | Everyone | Comprehensive overview | 10 min |
| **DEPLOYMENT_GUIDE.md** | Developers | Deploy to Cloud Run | 15 min |
| **DEPLOYMENT_CHECKLIST.md** | Deployers | Pre-flight verification | 5 min |
| **HACKATHON_SUMMARY.md** | Judges, Evaluators | Submission summary | 8 min |
| **INDEX.md** | Everyone | Navigate documentation | 3 min |

---

## 🏆 Success Criteria

### Deployment Success
- ✅ Backend deployed to Cloud Run
- ✅ Frontend connects to backend
- ✅ All 3 test policies work
- ✅ Simulation completes in <20s
- ✅ No errors in logs

### Demo Success
- ✅ Gatekeeper rejects bad policies
- ✅ Advisor generates Environment Blueprint
- ✅ Dashboard shows real-time updates
- ✅ Verdict provides AI recommendation

### Hackathon Success
- ✅ Live demo accessible to judges
- ✅ Documentation is comprehensive
- ✅ Technical innovation is clear
- ✅ Impact metrics are compelling

---

## 📧 Support

For questions or issues:
1. Check the relevant documentation file above
2. Review troubleshooting sections
3. Check Cloud Run logs
4. Test endpoints individually

---

**Built with ❤️ for Malaysia's 34 million citizens**

**#Project2030 #MyAIFuture #GovTech #MARL #PolicySimulation**
