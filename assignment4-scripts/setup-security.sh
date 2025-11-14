#!/bin/bash
# Assignment 4 - Exercise 1: Security Best Practices Setup
# This script enables necessary APIs and sets up security configurations

PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"

echo "Setting up Assignment 4 Security Best Practices for project: $PROJECT_ID"

# Enable necessary APIs for security
echo "Enabling required APIs..."
gcloud services enable \
    cloudkms.googleapis.com \
    cloudresourcemanager.googleapis.com \
    iam.googleapis.com \
    iap.googleapis.com \
    securitycenter.googleapis.com \
    container.googleapis.com \
    appengine.googleapis.com \
    sql-component.googleapis.com \
    storage.googleapis.com \
    monitoring.googleapis.com \
    logging.googleapis.com \
    artifactregistry.googleapis.com

echo "✅ APIs enabled successfully"

# Create service accounts with least privilege
echo "Creating service accounts with least privilege..."

# App Engine service account
gcloud iam service-accounts create flask-app-sa \
    --description="Service account for Flask application" \
    --display-name="Flask App SA"

# Cloud Functions service account
gcloud iam service-accounts create flask-functions-sa \
    --description="Service account for Cloud Functions" \
    --display-name="Flask Functions SA"

# KMS Crypto service account
gcloud iam service-accounts create kms-crypto-sa \
    --description="Service account for KMS operations" \
    --display-name="KMS Crypto SA"

echo "✅ Service accounts created"

# Set up IAM bindings with least privilege
echo "Setting up IAM bindings..."

# App Engine permissions
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:flask-app-sa@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/appengine.appViewer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:flask-app-sa@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/cloudsql.client"

# Cloud Functions permissions
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:flask-functions-sa@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/cloudfunctions.invoker"

# KMS permissions
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:kms-crypto-sa@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/cloudkms.cryptoKeyEncrypter"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:kms-crypto-sa@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/cloudkms.cryptoKeyDecrypter"

echo "✅ IAM bindings configured"

# Create KMS key ring and crypto key
echo "Setting up KMS encryption..."
gcloud kms keyrings create flask-keyring \
    --location=$REGION

gcloud kms keys create flask-encryption-key \
    --location=$REGION \
    --keyring=flask-keyring \
    --purpose=encryption \
    --rotation-period="86400s" \
    --next-rotation-time="$(date -d '+30 days' --iso-8601)"

echo "✅ KMS encryption key created"

# Grant access to KMS key for application service accounts
gcloud kms keys add-iam-policy-binding flask-encryption-key \
    --location=$REGION \
    --keyring=flask-keyring \
    --member="serviceAccount:flask-app-sa@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/cloudkms.cryptoKeyEncrypterDecrypter"

echo "✅ Assignment 4 Exercise 1 setup completed!"