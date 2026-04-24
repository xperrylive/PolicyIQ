#!/bin/bash
# deploy_cloud.sh — PolicyIQ Cloud Run Deployment Script
# Project 2030: MyAI Future Hackathon
#
# This script deploys the PolicyIQ backend to Google Cloud Run in the
# asia-southeast1 region (Singapore/Malaysia low-latency).
#
# Prerequisites:
#   1. gcloud CLI installed and authenticated
#   2. Docker installed (for local testing)
#   3. GROQ_API_KEY_1, GROQ_API_KEY_2, GROQ_API_KEY_3 set in your environment
#
# Usage:
#   ./deploy_cloud.sh

set -e

PROJECT_ID="policyiq2"
SERVICE_NAME="policyiq-backend"
REGION="asia-southeast1"
SOURCE_DIR="./backend"

echo "=========================================="
echo "  PolicyIQ Cloud Run Deployment"
echo "  Project: $PROJECT_ID"
echo "  Service: $SERVICE_NAME"
echo "  Region:  $REGION"
echo "=========================================="
echo ""

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "ERROR: gcloud CLI not found. Please install it first:"
    echo "https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Set the active project
echo "Setting active GCP project to $PROJECT_ID..."
gcloud config set project "$PROJECT_ID"

# Deploy to Cloud Run
echo ""
echo "Deploying $SERVICE_NAME to Cloud Run..."
echo ""

gcloud run deploy "$SERVICE_NAME" \
  --source="$SOURCE_DIR" \
  --region="$REGION" \
  --platform=managed \
  --allow-unauthenticated \
  --set-env-vars="GROQ_API_KEY_1=${GROQ_API_KEY_1:-placeholder-key-1}" \
  --set-env-vars="GROQ_API_KEY_2=${GROQ_API_KEY_2:-placeholder-key-2}" \
  --set-env-vars="GROQ_API_KEY_3=${GROQ_API_KEY_3:-placeholder-key-3}" \
  --set-env-vars="GROQ_MODEL=llama-3.3-70b-versatile" \
  --memory=2Gi \
  --cpu=2 \
  --timeout=300 \
  --max-instances=10 \
  --min-instances=0

echo ""
echo "=========================================="
echo "  Deployment Complete!"
echo "=========================================="
echo ""
echo "Your API is now live at:"
gcloud run services describe "$SERVICE_NAME" --region="$REGION" --format="value(status.url)"
echo ""
echo "Next steps:"
echo "  1. Copy the URL above"
echo "  2. Update frontend/lib/services/api_client.dart with the Cloud Run URL"
echo "  3. Rebuild your Flutter app"
echo ""
