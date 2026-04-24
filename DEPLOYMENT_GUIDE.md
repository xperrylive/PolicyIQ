# 🚀 PolicyIQ Deployment Guide
## Project 2030: MyAI Future Hackathon

This guide walks you through deploying PolicyIQ to Google Cloud Run for the hackathon demo.

---

## 📋 Pre-Deployment Checklist

### 1. Get Your Groq API Keys
PolicyIQ requires **3 Groq API keys** for load balancing across 50 concurrent agents.

1. Visit https://console.groq.com/
2. Sign up for a free account
3. Generate 3 API keys from the dashboard
4. Save them securely (you'll need them in Step 3)

**Why 3 keys?**  
Groq's free tier has rate limits. PolicyIQ distributes the 50 agents across 3 keys:
- Key 1: Agents 1-17 (B40 demographic)
- Key 2: Agents 18-34 (M40 demographic)
- Key 3: Agents 35-50 (T20 demographic)

This enables sub-second tick execution for all 50 agents simultaneously.

### 2. Install gcloud CLI
```bash
# macOS
brew install google-cloud-sdk

# Windows
# Download from: https://cloud.google.com/sdk/docs/install

# Linux
curl https://sdk.cloud.google.com | bash
```

Verify installation:
```bash
gcloud --version
```

### 3. Authenticate with GCP
```bash
gcloud auth login
gcloud config set project policyiq2
```

---

## ☁️ Cloud Run Deployment

### Step 1: Set Environment Variables
```bash
# Export your 3 Groq API keys
export GROQ_API_KEY_1="gsk_your_first_key_here"
export GROQ_API_KEY_2="gsk_your_second_key_here"
export GROQ_API_KEY_3="gsk_your_third_key_here"
```

**Important**: These keys are set as Cloud Run environment variables during deployment. They are NOT committed to your repository.

### Step 2: Run Deployment Script
```bash
# Make the script executable
chmod +x deploy_cloud.sh

# Deploy to Cloud Run
./deploy_cloud.sh
```

The script will:
1. Set your GCP project to `policyiq2`
2. Build the Docker image from `backend/Dockerfile`
3. Deploy to `asia-southeast1` (Singapore/Malaysia region for low latency)
4. Configure:
   - 2 GB memory
   - 2 vCPUs
   - 300-second timeout (for long simulations)
   - Auto-scaling: 0-10 instances
   - Public access (`--allow-unauthenticated`)

### Step 3: Get Your Cloud Run URL
After deployment completes, the script will output:
```
Your API is now live at:
https://policyiq-backend-abc123-as.a.run.app
```

**Copy this URL** — you'll need it for the Flutter frontend.

---

## 🎨 Frontend Configuration

### Step 1: Update API Base URL
Open `frontend/lib/services/api_client.dart` and update the base URL:

```dart
// BEFORE (local dev)
const String _kApiBaseUrl = 'http://127.0.0.1:8000';

// AFTER (Cloud Run)
const String _kApiBaseUrl = 'https://policyiq-backend-abc123-as.a.run.app';
```

### Step 2: Rebuild Flutter App
```bash
cd frontend
flutter clean
flutter pub get
flutter build web  # For web deployment
# OR
flutter build windows  # For Windows executable
# OR
flutter build macos  # For macOS app
```

### Step 3: Test the Connection
```bash
flutter run -d chrome
```

Try validating a policy in the Gatekeeper screen. If you see the AI response, your deployment is successful!

---

## 🧪 Testing Your Deployment

### Test 1: Health Check
```bash
curl https://policyiq-backend-abc123-as.a.run.app/health
```

Expected response:
```json
{"status": "ok", "service": "policyiq-backend"}
```

### Test 2: Policy Validation
```bash
curl -X POST https://policyiq-backend-abc123-as.a.run.app/validate-policy \
  -H "Content-Type: application/json" \
  -d '{"raw_policy_text": "Increase RON95 petrol price by 63% to RM3.35/litre"}'
```

Expected response:
```json
{
  "is_feasible": true,
  "environment_blueprint": {
    "policy_summary": "RON95 petrol price hike...",
    "universal_knobs": {...},
    "dynamic_sublayers": [...]
  }
}
```

### Test 3: Full Simulation (via Flutter)
1. Open the Flutter app
2. Enter a policy in the Gatekeeper screen
3. Click "Validate Policy"
4. If feasible, click "Run Simulation"
5. Watch the real-time SSE stream populate the dashboard

---

## 🔧 Troubleshooting

### Issue: "Permission denied" during deployment
**Solution**: Ensure you're authenticated and have the correct project set:
```bash
gcloud auth login
gcloud config set project policyiq2
```

### Issue: "Service account does not have permission"
**Solution**: Enable required APIs:
```bash
gcloud services enable run.googleapis.com
gcloud services enable cloudbuild.googleapis.com
```

### Issue: "Groq API rate limit exceeded"
**Solution**: 
1. Check that all 3 keys are set correctly in Cloud Run environment variables
2. View logs: `gcloud run logs read policyiq-backend --region=asia-southeast1`
3. If needed, add more keys and redeploy

### Issue: Flutter app shows "Backend is unreachable"
**Solution**:
1. Verify the Cloud Run URL is correct in `api_client.dart`
2. Check CORS is enabled (it is by default in `backend/main.py`)
3. Test the `/health` endpoint directly in your browser

---

## 📊 Monitoring Your Deployment

### View Logs
```bash
gcloud run logs read policyiq-backend --region=asia-southeast1 --limit=50
```

### View Metrics (Cloud Console)
1. Visit https://console.cloud.google.com/run
2. Select `policyiq-backend`
3. Click "Metrics" tab to see:
   - Request count
   - Request latency
   - Container CPU/memory usage
   - Error rate

### Set Up Alerts (Optional)
```bash
# Alert if error rate > 5%
gcloud alpha monitoring policies create \
  --notification-channels=YOUR_CHANNEL_ID \
  --display-name="PolicyIQ Error Rate Alert" \
  --condition-display-name="Error rate > 5%" \
  --condition-threshold-value=0.05 \
  --condition-threshold-duration=60s
```

---

## 💰 Cost Estimation

**Cloud Run Pricing** (asia-southeast1):
- **CPU**: $0.00002400 per vCPU-second
- **Memory**: $0.00000250 per GB-second
- **Requests**: $0.40 per million requests

**Estimated Hackathon Cost** (100 simulations):
- 100 simulations × 30 seconds × 2 vCPUs × $0.000024 = **$0.14**
- 100 simulations × 30 seconds × 2 GB × $0.0000025 = **$0.015**
- 100 requests × $0.0000004 = **$0.00004**

**Total**: ~$0.16 for the entire hackathon demo period

**Free Tier**: Cloud Run includes 2 million requests/month free, so your demo will likely cost $0.

---

## 🔒 Security Notes

### For Hackathon Demo
- `--allow-unauthenticated` is enabled so judges can access the API
- CORS is set to `allow_origins=["*"]` for easy frontend integration

### For Production Deployment
If you continue this project post-hackathon, tighten security:

1. **Restrict CORS**:
```python
# backend/main.py
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://your-flutter-app-domain.com"],  # Specific domain
    allow_credentials=True,
    allow_methods=["POST", "GET"],
    allow_headers=["Content-Type"],
)
```

2. **Add Authentication**:
```bash
gcloud run deploy policyiq-backend \
  --no-allow-unauthenticated  # Require authentication
```

3. **Add Rate Limiting**:
```python
# backend/main.py
from slowapi import Limiter
limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter

@app.post("/simulate")
@limiter.limit("10/minute")  # Max 10 simulations per minute per IP
async def simulate(...):
    ...
```

---

## 🎯 Next Steps After Deployment

1. **Test thoroughly**: Run 5-10 simulations with different policies
2. **Record a demo video**: Show the full Governor's Journey (Gatekeeper → Advisor → Dashboard → Verdict)
3. **Prepare your pitch**: Use the README.md as your script
4. **Share the Cloud Run URL**: Include it in your hackathon submission
5. **Monitor logs**: Watch for any errors during the judging period

---

## 📞 Support

If you encounter issues during deployment:
1. Check the logs: `gcloud run logs read policyiq-backend --region=asia-southeast1`
2. Review the troubleshooting section above
3. Test each endpoint individually using `curl`
4. Verify environment variables are set correctly in Cloud Run console

---

**Good luck with your hackathon demo! 🚀**
