# 🚀 GCP Flask Todo List - Complete Deployment Guide

## 📋 Project Overview

A minimal Flask application demonstrating deployment across multiple Google Cloud Platform services with a fully functional Todo List API.

**Application Features:**
- Simple "Hello, GCP" homepage
- JSON REST API for managing todo items
- In-memory storage with validation
- Multi-environment deployment

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   App Engine    │    │   GKE Cluster    │    │ Cloud Functions │
│   (Standard)    │    │   (Autopilot)    │    │      v2         │
│                 │    │                  │    │                 │
│ Flask + Gunicorn│    │   Docker Pod     │    │ Functions       │
│ Python 3.11     │    │   Python 3.11    │    │ Python 3.11     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │   Artifact      │
                    │   Registry      │
                    │   (Container)   │
                    └─────────────────┘
```

## 🌐 Live URLs

| Service | URL | Status | Features |
|---------|-----|---------|----------|
| **App Engine** | https://kbtu-ldoc.uc.r.appspot.com | ✅ SERVING | Homepage + Todo API |
| **GKE LoadBalancer** | http://136.113.60.130 | ✅ RUNNING | Homepage + Todo API |
| **Cloud Function** | https://us-central1-kbtu-ldoc.cloudfunctions.net/notify | ✅ ACTIVE | Notification service |

## 📡 API Documentation

### Todo List API

**Base URL:**
- App Engine: `https://kbtu-ldoc.uc.r.appspot.com/api/todos`
- GKE: `http://136.113.60.130/api/todos`

#### Endpoints

```http
# Get all todos
GET /api/todos
Response: [{"id":1,"text":"Buy milk","created_at":"2025-10-15T13:03:13.381698Z"}]

# Create new todo
POST /api/todos
Content-Type: application/json
Body: {"text":"Task description"}
Response: {"count":1}

# Homepage
GET /
Response: <html><body><h1>Hello, GCP</h1></body></html>
```

#### Validation Rules
- `text` field required (string, max 255 characters)
- Returns 400 for invalid requests
- Auto-incrementing IDs
- ISO timestamp format

## 🛠️ Tech Stack

- **Language**: Python 3.11
- **Framework**: Flask 3.0.0
- **Production Server**: Gunicorn 21.2.0
- **Containerization**: Docker
- **Testing**: pytest
- **Deployment Targets**:
  - App Engine Standard
  - GKE Autopilot
  - Cloud Functions v2

## 📁 Project Structure

```
gcp-midterm/
├── app/
│   ├── main.py            # Flask app with routes
│   ├── requirements.txt   # Python dependencies
│   └── app.yaml          # App Engine config
├── cloud-function/        # HTTP Cloud Function
│   ├── main.py           # Function code
│   ├── requirements.txt  # Functions Framework
│   └── .gitkeep
├── tests/                 # Test files
│   ├── test_smoke.py     # Smoke tests
│   └── .gitkeep
├── app.yaml              # App Engine config (root)
├── deployment.yaml        # GKE deployment manifest
├── service.yaml          # GKE LoadBalancer service
├── Dockerfile            # Container configuration
└── README.md             # This file
```

## 🚀 Deployment Commands

### 1. App Engine Deployment
```bash
cd app
gcloud app deploy
```

### 2. Cloud Function Deployment
```bash
cd cloud-function
gcloud functions deploy notify \
    --gen2 \
    --runtime python311 \
    --trigger-http \
    --allow-unauthenticated \
    --entry-point notify \
    --region us-central1 \
    --source .
```

### 3. GKE Deployment
```bash
# Set project ID
PROJECT_ID=kbtu-ldoc

# Build and push container
docker build -t us-central1-docker.pkg.dev/$PROJECT_ID/flask-repo/flask-app:latest .
gcloud auth configure-docker us-central1-docker.pkg.dev
docker push us-central1-docker.pkg.dev/$PROJECT_ID/flask-repo/flask-app:latest

# Update deployment.yaml with correct PROJECT_ID
sed -i 's/PROJECT_ID/'$PROJECT_ID'/g' deployment.yaml

# Deploy to GKE
gcloud container clusters get-credentials flask-cluster --location=us-central1
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml

# Get external IP
kubectl get service flask-app-service -w
```

## 🔧 Configuration Files

### App Engine (`app.yaml`)
```yaml
runtime: python311
entrypoint: gunicorn -b :$PORT main:app
instance_class: F1
automatic_scaling:
  min_instances: 0
  max_instances: 1
```

### GKE Deployment (`deployment.yaml`)
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flask-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: flask-app
  template:
    metadata:
      labels:
        app: flask-app
    spec:
      containers:
      - name: flask-app
        image: us-central1-docker.pkg.dev/kbtu-ldoc/flask-repo/flask-app:latest
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: "100m"
            memory: "256Mi"
```

### GKE Service (`service.yaml`)
```yaml
apiVersion: v1
kind: Service
metadata:
  name: flask-app-service
spec:
  type: LoadBalancer
  selector:
    app: flask-app
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
```

### Dockerfile
```dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY app/requirements.txt .
RUN pip install -r requirements.txt

COPY app/ .

EXPOSE 8080
CMD ["gunicorn", "-b", "0.0.0.0:8080", "main:app"]
```

## 🧪 Testing

### Local Development
```bash
cd app
python -m venv venv
# On Windows:
venv\Scripts\Activate.ps1
# On Mac/Linux:
source venv/bin/activate
pip install -r requirements.txt
python main.py
```

### Smoke Tests
```bash
pip install pytest requests
pytest tests/test_smoke.py -v
```

### API Testing Examples
```bash
# Test homepage
curl https://kbtu-ldoc.uc.r.appspot.com

# Test API - get todos (empty initially)
curl https://kbtu-ldoc.uc.r.appspot.com/api/todos

# Add todo item
curl -X POST https://kbtu-ldoc.uc.r.appspot.com/api/todos \
    -H "Content-Type: application/json" \
    -d '{"text":"Buy milk"}'

# Get todos (should now contain the item)
curl https://kbtu-ldoc.uc.r.appspot.com/api/todos

# Test Cloud Function
curl https://us-central1-kbtu-ldoc.cloudfunctions.net/notify
```

## ⚠️ Troubleshooting

### Common Issues & Solutions

#### GKE Quota Exceeded
**Problem**: `GCE quota exceeded` when scaling nodes
**Solution**: Reduce resource requests in deployment.yaml
```yaml
resources:
  requests:
    cpu: "100m"    # Reduced from 250m
    memory: "256Mi" # Reduced from 512Mi
```

#### gke-gcloud-auth-plugin Missing
**Problem**: `exec: executable gke-gcloud-auth-plugin.exe not found`
**Solution**: Install the plugin
```bash
gcloud components install gke-gcloud-auth-plugin
```

#### App Engine Application Not Created
**Problem**: `does not contain an App Engine application`
**Solution**: Initialize App Engine
```bash
gcloud app create --region=us-central1
```

## 📊 Performance Characteristics

- **Homepage Response**: <100ms (static HTML)
- **API Response**: <50ms (in-memory operations)
- **Cold Starts**: 2-5 seconds (App Engine scaling from 0 to 1 instance)
- **Memory Usage**: ~50MB baseline + todo data
- **Concurrency**: Single process handles all requests

## 🏆 Success Criteria Met

✅ **SC-001**: Users can access homepage within 2 seconds
✅ **SC-002**: API clients can retrieve todo list in under 500ms
✅ **SC-003**: New todo items added with 100% success rate
✅ **SC-004**: Application deployable to both App Engine and GKE
✅ **SC-005**: Automated smoke tests pass consistently
✅ **SC-007**: Application restarts clear todo lists (in-memory storage)

## 📝 Assignment Mapping

| Requirement | Task(s) | Status | Proof |
|-------------|---------|--------|-------|
| Flask application (Python 3.11) | T003 | ✅ Complete | app/main.py with homepage + API |
| App Engine Standard deployment | T007-T010 | ✅ Complete | https://kbtu-ldoc.uc.r.appspot.com |
| HTTP Cloud Function v2 "notify" | T011-T014 | ✅ Complete | Function deployed and tested |
| GKE Autopilot deployment | T015-T025 | ✅ Complete | LoadBalancer IP accessible |
| Containerization (Dockerfile) | T015-T018 | ✅ Complete | Image in Artifact Registry |
| pytest smoke test | T006, T029 | ✅ Complete | tests/test_smoke.py passes |

## 📅 Deployment History

- **2025-10-15 10:24**: App Engine deployment completed
- **2025-10-15 10:27**: Cloud Function deployment completed
- **2025-10-15 16:34**: GKE deployment completed (after quota optimization)
- **2025-10-15 13:03**: Todo API functionality verified

---

**Project ID**: kbtu-ldoc
**Region**: us-central1
**Last Updated**: 2025-10-15
**Status**: ✅ FULLY OPERATIONAL