#!/bin/bash

# Set environment variables (replace with your actual values)
PROJECT_ID=$(gcloud config get-value project)
REGION="northamerica-south1"
IMAGE_NAME="northamerica-south1-docker.pkg.dev/$PROJECT_ID/docker-images/db-service"
SERVICE_NAME="db-service"
SERVICE_ACCOUNT="run-sa@$PROJECT_ID.iam.gserviceaccount.com"
SUBNET="northamerica-south1-vpc-egress"

docker build -t $IMAGE_NAME ../cloudrun/db-service

# Push the Docker image to Google Container Registry
docker push $IMAGE_NAME

# Deploy to Cloud Run
gcloud run deploy $SERVICE_NAME \
  --image $IMAGE_NAME \
  --platform managed \
  --region $REGION \
  --set-env-vars MAX_CONNECTIONS=100,PRIVATE_IP=true,DB_IAM_USER=function-sa,SECRET_NAME=db-conn,PROJECT_ID=$PROJECT_ID \
  --service-account $SERVICE_ACCOUNT \
  --vpc-egress private-ranges-only \
  --subnet $SUBNET \
  --ingress internal \
  --no-allow-unauthenticated \
  --cpu-boost \
  --min 1
  --min-instances 5 \
  --max-instances 25



echo "Deployment complete.  Service URL: $(gcloud run services describe $SERVICE_NAME --region $REGION --format='value(status.url)')"
