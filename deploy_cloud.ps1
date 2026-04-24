# deploy_cloud.ps1 — PolicyIQ Cloud Run Deployment Script (Windows PowerShell)
# Project 2030: MyAI Future Hackathon
#
# This script deploys the PolicyIQ backend to Google Cloud Run in the
# asia-southeast1 region (Singapore/Malaysia low-latency).
#
# Prerequisites:
#   1. gcloud CLI installed and authenticated
#   2. GROQ_API_KEY_1, GROQ_API_KEY_2, GROQ_API_KEY_3 set in your environment
#
# Usage:
#   .\deploy_cloud.ps1

$PROJECT_ID = "policyiq2"
$SERVICE_NAME = "policyiq-backend"
$REGION = "asia-southeast1"
$SOURCE_DIR = ".\backend"

Write-Host "==========================================" -ForegroundColor Green
Write-Host "  PolicyIQ Cloud Run Deployment" -ForegroundColor Green
Write-Host "  Project: $PROJECT_ID" -ForegroundColor Green
Write-Host "  Service: $SERVICE_NAME" -ForegroundColor Green
Write-Host "  Region:  $REGION" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""

# Check if gcloud is installed
if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: gcloud CLI not found. Please install it first:" -ForegroundColor Red
    Write-Host "https://cloud.google.com/sdk/docs/install" -ForegroundColor Red
    exit 1
}

# Check if Groq API keys are set
if (-not $env:GROQ_API_KEY_1) {
    Write-Host "ERROR: GROQ_API_KEY_1 environment variable not set" -ForegroundColor Red
    Write-Host "Please run: `$env:GROQ_API_KEY_1='your-key-here'" -ForegroundColor Yellow
    exit 1
}

if (-not $env:GROQ_API_KEY_2) {
    Write-Host "ERROR: GROQ_API_KEY_2 environment variable not set" -ForegroundColor Red
    Write-Host "Please run: `$env:GROQ_API_KEY_2='your-key-here'" -ForegroundColor Yellow
    exit 1
}

if (-not $env:GROQ_API_KEY_3) {
    Write-Host "ERROR: GROQ_API_KEY_3 environment variable not set" -ForegroundColor Red
    Write-Host "Please run: `$env:GROQ_API_KEY_3='your-key-here'" -ForegroundColor Yellow
    exit 1
}

# Set the active project
Write-Host "Setting active GCP project to $PROJECT_ID..." -ForegroundColor Yellow
gcloud config set project $PROJECT_ID

# Deploy to Cloud Run
Write-Host ""
Write-Host "Deploying $SERVICE_NAME to Cloud Run..." -ForegroundColor Yellow
Write-Host ""

gcloud run deploy $SERVICE_NAME `
  --source=$SOURCE_DIR `
  --region=$REGION `
  --platform=managed `
  --allow-unauthenticated `
  --set-env-vars="GROQ_API_KEY_1=$env:GROQ_API_KEY_1" `
  --set-env-vars="GROQ_API_KEY_2=$env:GROQ_API_KEY_2" `
  --set-env-vars="GROQ_API_KEY_3=$env:GROQ_API_KEY_3" `
  --set-env-vars="GROQ_MODEL=llama-3.3-70b-versatile" `
  --memory=2Gi `
  --cpu=2 `
  --timeout=300 `
  --max-instances=10 `
  --min-instances=0

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  Deployment Complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Your API is now live at:" -ForegroundColor Green
gcloud run services describe $SERVICE_NAME --region=$REGION --format="value(status.url)"
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Copy the URL above" -ForegroundColor White
Write-Host "  2. Update frontend/lib/services/api_client.dart with the Cloud Run URL" -ForegroundColor White
Write-Host "  3. Rebuild your Flutter app" -ForegroundColor White
Write-Host ""