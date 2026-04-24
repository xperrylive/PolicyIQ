# ✅ PolicyIQ Deployment Checklist
## Project 2030: MyAI Future Hackathon

Use this checklist to ensure your deployment is production-ready for the hackathon demo.

---

## 📋 Pre-Deployment

### Environment Setup
- [ ] Obtained 3 Groq API keys from https://console.groq.com/
- [ ] Installed gcloud CLI (`gcloud --version`)
- [ ] Authenticated with GCP (`gcloud auth login`)
- [ ] Set project to policyiq2 (`gcloud config set project policyiq2`)
- [ ] Created `.env` file from `.env.example`
- [ ] Added all 3 Groq keys to `.env`

### Code Quality
- [ ] Removed debug `print()` statements (or added `# ignore: avoid_print`)
- [ ] Verified CORS is set to `allow_origins=["*"]` in `backend/main.py`
- [ ] Confirmed `--allow-unauthenticated` flag in `deploy_cloud.sh`
- [ ] Tested backend locally with Docker (`docker-compose up`)
- [ ] Tested Flutter frontend locally (`flutter run -d chrome`)

### Documentation
- [ ] README.md is complete and professional
- [ ] DEPLOYMENT_GUIDE.md has correct Cloud Run URL placeholders
- [ ] QUICK_START.md has sample policies to test
- [ ] All markdown files use proper formatting

---

## ☁️ Cloud Run Deployment

### Deployment Steps
- [ ] Exported 3 Groq API keys as environment variables:
  ```bash
  export GROQ_API_KEY_1="gsk_..."
  export GROQ_API_KEY_2="gsk_..."
  export GROQ_API_KEY_3="gsk_..."
  ```
- [ ] Made deployment script executable (`chmod +x deploy_cloud.sh`)
- [ ] Ran deployment script (`./deploy_cloud.sh`)
- [ ] Deployment completed without errors
- [ ] Copied Cloud Run URL from output

### Post-Deployment Verification
- [ ] Health check passes:
  ```bash
  curl https://your-cloud-run-url/health
  ```
  Expected: `{"status": "ok", "service": "policyiq-backend"}`

- [ ] API docs accessible:
  ```
  https://your-cloud-run-url/docs
  ```

- [ ] Policy validation works:
  ```bash
  curl -X POST https://your-cloud-run-url/validate-policy \
    -H "Content-Type: application/json" \
    -d '{"raw_policy_text": "Increase RON95 to RM3.35/litre"}'
  ```
  Expected: JSON response with `is_feasible: true`

---

## 🎨 Flutter Frontend Configuration

### Update API Base URL
- [ ] Opened `frontend/lib/services/api_client.dart`
- [ ] Updated `_kApiBaseUrl` to Cloud Run URL:
  ```dart
  const String _kApiBaseUrl = 'https://your-cloud-run-url';
  ```
- [ ] Saved file

### Build & Test
- [ ] Ran `flutter clean`
- [ ] Ran `flutter pub get`
- [ ] Built for target platform:
  - [ ] Web: `flutter build web`
  - [ ] Windows: `flutter build windows`
  - [ ] macOS: `flutter build macos`
- [ ] Tested connection to Cloud Run backend
- [ ] Validated a policy successfully
- [ ] Ran a full simulation (4 ticks, 50 agents)

---

## 🧪 End-to-End Testing

### Test Case 1: Good Policy (Should Pass Gatekeeper)
- [ ] Policy: "Implement a targeted RM100 monthly cash transfer to B40 households via PADU"
- [ ] Gatekeeper returns `is_feasible: true`
- [ ] Environment Blueprint generated with 8 knobs + 3-5 sublayers
- [ ] Simulation runs successfully
- [ ] Dashboard shows real-time tick updates
- [ ] Final verdict includes AI recommendation

### Test Case 2: Bad Policy (Should Be Rejected)
- [ ] Policy: "Make everything cheaper for everyone"
- [ ] Gatekeeper returns `is_feasible: false`
- [ ] 3 refined alternatives provided
- [ ] 3 strategic suggestions provided
- [ ] No simulation runs (blocked by Gatekeeper)

### Test Case 3: Controversial Policy (Should Simulate with Warnings)
- [ ] Policy: "Remove RON95 subsidy, increase price to RM3.35/litre"
- [ ] Gatekeeper returns `is_feasible: true`
- [ ] Simulation shows negative B40 sentiment (-0.6 to -0.8)
- [ ] Breaking points detected (15-20 agents)
- [ ] AI recommendation suggests mitigation (e.g., transport voucher)

---

## 📊 Performance Verification

### Backend Performance
- [ ] Health check responds in <100ms
- [ ] Policy validation completes in <3 seconds
- [ ] Single simulation tick (50 agents) completes in <5 seconds
- [ ] Full simulation (4 ticks) completes in <20 seconds
- [ ] No Groq API rate limit errors in logs

### Frontend Performance
- [ ] Gatekeeper screen loads in <1 second
- [ ] SSE stream updates dashboard in real-time
- [ ] No UI freezing during simulation
- [ ] Charts render smoothly (radar, Sankey)
- [ ] Anomaly hunter updates live

---

## 🔒 Security & Configuration

### Cloud Run Settings
- [ ] Region: `asia-southeast1` (Singapore/Malaysia)
- [ ] Memory: 2 GB
- [ ] CPU: 2 vCPUs
- [ ] Timeout: 300 seconds
- [ ] Max instances: 10
- [ ] Min instances: 0 (auto-scale to zero)
- [ ] Authentication: `--allow-unauthenticated` (for hackathon)

### Environment Variables (Cloud Run)
- [ ] `GROQ_API_KEY_1` set correctly
- [ ] `GROQ_API_KEY_2` set correctly
- [ ] `GROQ_API_KEY_3` set correctly
- [ ] `GROQ_MODEL` = `llama-3.3-70b-versatile`

### CORS Configuration
- [ ] `allow_origins=["*"]` (hackathon demo)
- [ ] `allow_methods=["*"]`
- [ ] `allow_headers=["*"]`

---

## 📹 Demo Preparation

### Recording Setup
- [ ] Screen recording software ready (OBS, QuickTime, etc.)
- [ ] Microphone tested
- [ ] Browser zoom set to 100%
- [ ] Unnecessary browser tabs closed
- [ ] Notifications disabled

### Demo Script
- [ ] Introduction (30 seconds): "PolicyIQ is SimCity for Malaysian government policy..."
- [ ] Gatekeeper Demo (1 minute): Show rejection + refinement
- [ ] Advisor Demo (1 minute): Show Environment Blueprint generation
- [ ] Dashboard Demo (2 minutes): Run live simulation, show real-time updates
- [ ] Verdict Demo (1 minute): Show AI recommendation + export report
- [ ] Closing (30 seconds): "Impacting 34 million Malaysians..."

### Sample Policies Ready
- [ ] Good policy text copied to clipboard
- [ ] Bad policy text copied to clipboard
- [ ] Controversial policy text copied to clipboard

---

## 🐛 Troubleshooting Checklist

### If Backend Fails to Deploy
- [ ] Check gcloud authentication: `gcloud auth list`
- [ ] Verify project: `gcloud config get-value project`
- [ ] Enable required APIs:
  ```bash
  gcloud services enable run.googleapis.com
  gcloud services enable cloudbuild.googleapis.com
  ```
- [ ] Check deployment logs:
  ```bash
  gcloud run logs read policyiq-backend --region=asia-southeast1
  ```

### If Frontend Can't Connect
- [ ] Verify Cloud Run URL is correct in `api_client.dart`
- [ ] Test `/health` endpoint in browser
- [ ] Check browser console for CORS errors
- [ ] Verify backend is running: `gcloud run services list`

### If Simulation Fails
- [ ] Check Groq API keys are valid
- [ ] Verify all 3 keys are set in Cloud Run
- [ ] Check for rate limit errors in logs
- [ ] Test with fewer agents (5 instead of 50)

---

## 📦 Submission Checklist

### GitHub Repository
- [ ] All code committed and pushed
- [ ] `.env` file is in `.gitignore` (secrets not committed)
- [ ] README.md is the main landing page
- [ ] DEPLOYMENT_GUIDE.md is complete
- [ ] QUICK_START.md is accessible
- [ ] Repository is public (or judges have access)

### Hackathon Submission Form
- [ ] Project name: "PolicyIQ — SimCity for GovTech"
- [ ] Cloud Run URL included
- [ ] GitHub repository URL included
- [ ] Demo video uploaded (if required)
- [ ] Team member names listed
- [ ] Technology stack documented

### Demo Video (if required)
- [ ] Video length: 3-5 minutes
- [ ] Shows full Governor's Journey (4 stages)
- [ ] Demonstrates live simulation with 50 agents
- [ ] Highlights key innovation (3-key load balancing)
- [ ] Explains impact (34 million Malaysians)
- [ ] Uploaded to YouTube/Vimeo with public link

---

## 🎯 Final Checks

### Before Judging Period
- [ ] Cloud Run service is running (not stopped)
- [ ] Test all 3 sample policies one more time
- [ ] Verify logs show no errors
- [ ] Confirm Flutter app connects successfully
- [ ] Check that API docs are accessible

### During Judging Period
- [ ] Monitor Cloud Run logs for traffic
- [ ] Check for any error spikes
- [ ] Be ready to answer technical questions
- [ ] Have architecture diagram ready (if needed)

---

## 🎉 Post-Deployment

### Success Criteria
- ✅ Backend deployed to Cloud Run
- ✅ Frontend connects to Cloud Run backend
- ✅ All 3 test cases pass
- ✅ Simulation completes in <20 seconds
- ✅ No errors in logs
- ✅ Demo video recorded
- ✅ Submission form completed

### Optional Enhancements (if time permits)
- [ ] Add custom domain to Cloud Run
- [ ] Deploy Flutter web app to Firebase Hosting
- [ ] Set up Cloud Monitoring alerts
- [ ] Create architecture diagram
- [ ] Add more sample policies to QUICK_START.md

---

**Deployment Status**: ⬜ Not Started | 🟡 In Progress | ✅ Complete

**Last Updated**: [Date]

**Deployed By**: [Your Name]

**Cloud Run URL**: `https://policyiq-backend-______-as.a.run.app`

---

**Good luck with your hackathon submission! 🚀**
