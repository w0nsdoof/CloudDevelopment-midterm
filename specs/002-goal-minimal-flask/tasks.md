---
description: "Task list for minimal Flask app with GCP deployment"
---

# Tasks: Minimal Flask App with GCP Deployment

**Input**: Design documents from `/specs/002-goal-minimal-flask/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/api.yaml

**Tests**: Basic smoke test included (FR-009 requirement)

**Organization**: Tasks are grouped by deployment milestones and user stories to enable independent implementation and testing of each component.

## Format: `[ID] [P?] [Story] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths and commands in descriptions

---

## Phase 1: Setup (Project Structure)

**Purpose**: Project initialization and repository structure

- [ ] T001 Create repository structure per implementation plan
  **Output**: Create directories `app/`, `cloud-function/`, `tests/` at repository root
  **PowerShell Commands**:
  ```powershell
  New-Item -ItemType Directory -Path "app" -Force
  New-Item -ItemType Directory -Path "cloud-function" -Force
  New-Item -ItemType Directory -Path "tests" -Force
  ```
  **Skipping note**: Skipped if repository already has required directory structure

- [ ] T002 [P] Create initial README.md with deployment mapping template
  **Output**: Create `README.md` with sections for each GCP service and skip tracking
  **Skipping note**: Skipped if README.md already exists with proper structure

---

## Phase 2: Foundational (Flask Application Core)

**Purpose**: Core Flask application that serves both user stories

**⚠️ CRITICAL**: No deployment work can begin until this phase is complete

- [ ] T003 Create Flask application with homepage and todo API in `app/main.py`
  **Output**: Complete Flask app with routes for `/` and `/api/todos`
  **File Contents**:
  ```python
  from flask import Flask, jsonify, request
  from datetime import datetime

  app = Flask(__name__)
  todos = []
  next_id = 1

  @app.route('/')
  def home():
      return '<html><body><h1>Hello, GCP</h1></body></html>'

  @app.route('/api/todos', methods=['GET'])
  def get_todos():
      return jsonify(todos)

  @app.route('/api/todos', methods=['POST'])
  def create_todo():
      global next_id

      data = request.get_json()
      if not data or 'text' not in data:
          return jsonify({'error': 'text field is required'}), 400

      text = data['text'].strip()
      if not text:
          return jsonify({'error': 'text cannot be empty'}), 400

      if len(text) > 255:
          return jsonify({'error': 'text maximum 255 characters'}), 400

      todo = {
          'id': next_id,
          'text': text,
          'created_at': datetime.utcnow().isoformat() + 'Z'
      }

      todos.append(todo)
      next_id += 1

      return jsonify({'count': len(todos)}), 201

  if __name__ == '__main__':
      app.run(host='0.0.0.0', port=8080, debug=True)
  ```
  **Skipping note**: Skipped if Flask app already exists with required routes

- [ ] T004 [P] Create Python requirements file in `app/requirements.txt`
  **Output**: Dependencies file for Flask and production server
  **File Contents**:
  ```
  flask==3.0.0
  gunicorn==21.2.0
  ```
  **Skipping note**: Skipped if requirements.txt already contains Flask and Gunicorn

- [ ] T005 Create App Engine deployment configuration in `app.yaml`
  **Output**: App Engine Standard configuration for Python 3.11
  **File Contents**:
  ```yaml
  runtime: python311
  entrypoint: gunicorn -b :$PORT main:app
  instance_class: F1
  automatic_scaling:
    min_instances: 0
    max_instances: 1
  ```
  **Skipping note**: Skipped if app.yaml already exists with proper configuration

- [ ] T006 Create basic smoke test in `tests/test_smoke.py`
  **Output**: pytest test for homepage verification (FR-009 requirement)
  **File Contents**:
  ```python
  import requests
  import pytest

  def test_homepage():
      """Test that homepage returns 200 status"""
      response = requests.get('http://localhost:8080', timeout=10)
      assert response.status_code == 200
      assert 'Hello, GCP' in response.text
  ```
  **Skipping note**: Skipped if smoke test already exists and passes

**Checkpoint**: Flask application foundation ready - all deployment targets can now proceed

---

## Phase 3: App Engine Deployment (Milestone 1)

**Goal**: Deploy Flask application to App Engine Standard

**Independent Test**: Access https://your-project.appspot.com and verify "Hello, GCP" appears with 200 status

- [ ] T007 Enable required GCP services for App Engine
  **Output**: App Engine Admin API and Cloud Build API enabled
  **PowerShell Commands**:
  ```powershell
  gcloud services enable appengine.googleapis.com
  gcloud services enable cloudbuild.googleapis.com
  ```
  **Skipping note**: Skipped if services already enabled (error: already enabled)

- [ ] T008 Create App Engine application (if not exists)
  **Output**: App Engine app created in default region
  **PowerShell Commands**:
  ```powershell
  gcloud app create --region=us-central1
  ```
  **Skipping note**: Skipped if App Engine app already exists (error: already exists)

- [ ] T009 Deploy Flask application to App Engine
  **Output**: Flask app deployed and accessible via project URL
  **PowerShell Commands**:
  ```powershell
  cd app
  gcloud app deploy
  ```
  **Skipping note**: Skipped if deployment fails due to permissions or configuration errors

- [ ] T010 Verify App Engine deployment and open browser
  **Output**: Browser opens to deployed application
  **PowerShell Commands**:
  ```powershell
  $PROJECT_ID = gcloud config get-value project
  Start-Process "https://$PROJECT_ID.appspot.com"
  ```
  **Skipping note**: Skipped if deployment verification fails or app is inaccessible

**Checkpoint**: App Engine deployment complete and verified - User Story 1 (homepage) works

---

## Phase 4: Cloud Function Deployment (Milestone 2)

**Goal**: Deploy independent HTTP Cloud Function for notifications

**Independent Test**: Access Cloud Function URL and verify JSON response with 200 status

- [ ] T011 [P] Create HTTP Cloud Function code in `cloud-function/main.py`
  **Output**: Simple HTTP function returning notification message
  **File Contents**:
  ```python
  import functions_framework

  @functions_framework.http
  def notify(request):
      return {"message": "Notification sent from Cloud Function", "timestamp": "2025-10-15"}, 200
  ```
  **Skipping note**: Skipped if cloud function code already exists with proper structure

- [ ] T012 [P] Create Cloud Function requirements file in `cloud-function/requirements.txt`
  **Output**: Functions Framework dependency
  **File Contents**:
  ```
  functions-framework==3.*
  ```
  **Skipping note**: Skipped if requirements.txt already exists in cloud-function directory

- [ ] T013 Enable Cloud Functions API
  **Output**: Cloud Functions API enabled for deployment
  **PowerShell Commands**:
  ```powershell
  gcloud services enable cloudfunctions.googleapis.com
  ```
  **Skipping note**: Skipped if API already enabled

- [ ] T014 Deploy HTTP Cloud Function "notify" (Gen2)
  **Output**: Cloud Function deployed with public access
  **PowerShell Commands**:
  ```powershell
  cd cloud-function
  gcloud functions deploy notify `
      --gen2 `
      --runtime python311 `
      --trigger-http `
      --allow-unauthenticated `
      --entry-point notify `
      --region us-central1 `
      --source .
  ```
  **Skipping note**: Skipped if deployment fails due to IAM or permission errors

**Checkpoint**: Cloud Function deployed and working - User Story 2 (serverless demo) works

---

## Phase 5: Container Build and Artifact Registry (Milestone 3)

**Goal**: Containerize Flask application for GKE deployment

**Independent Test**: Verify container image exists in Artifact Registry

- [ ] T015 [P] Create Dockerfile for containerization
  **Output**: Dockerfile with Python 3.11 base and Gunicorn
  **File Contents**:
  ```dockerfile
  FROM python:3.11-slim

  WORKDIR /app
  COPY app/requirements.txt .
  RUN pip install -r requirements.txt

  COPY app/ .

  EXPOSE 8080
  CMD ["gunicorn", "-b", "0.0.0.0:8080", "main:app"]
  ```
  **Skipping note**: Skipped if Dockerfile already exists with proper configuration

- [ ] T016 Enable Artifact Registry API
  **Output**: Artifact Registry API enabled for container storage
  **PowerShell Commands**:
  ```powershell
  gcloud services enable artifactregistry.googleapis.com
  ```
  **Skipping note**: Skipped if API already enabled

- [ ] T017 Create Artifact Registry repository
  **Output**: Docker repository for container images
  **PowerShell Commands**:
  ```powershell
  $PROJECT_ID = gcloud config get-value project
  gcloud artifacts repositories create flask-repo `
      --repository-format=docker `
      --location=us-central1 `
      --description="Flask app Docker images"
  ```
  **Skipping note**: Skipped if repository already exists

- [ ] T018 Build and push container image with Cloud Build
  **Output**: Flask container image pushed to Artifact Registry
  **PowerShell Commands**:
  ```powershell
  $PROJECT_ID = gcloud config get-value project
  docker build -t us-central1-docker.pkg.dev/$PROJECT_ID/flask-repo/flask-app:latest .
  gcloud auth configure-docker us-central1-docker.pkg.dev
  docker push us-central1-docker.pkg.dev/$PROJECT_ID/flask-repo/flask-app:latest
  ```
  **Skipping note**: Skipped if build fails or push fails due to authentication errors

**Checkpoint**: Container image ready in Artifact Registry - Ready for GKE deployment

---

## Phase 6: GKE Autopilot Cluster (Milestone 4)

**Goal**: Create GKE Autopilot cluster for container deployment

**Independent Test**: Verify cluster exists and kubectl can connect

- [ ] T019 Enable GKE and Container Registry APIs
  **Output**: Required APIs for GKE operations enabled
  **PowerShell Commands**:
  ```powershell
  gcloud services enable container.googleapis.com
  gcloud services enable containerregistry.googleapis.com
  ```
  **Skipping note**: Skipped if APIs already enabled

- [ ] T020 Create GKE Autopilot cluster
  **Output**: GKE Autopilot cluster ready for workloads
  **PowerShell Commands**:
  ```powershell
  gcloud container clusters create-auto flask-cluster `
      --region=us-central1 `
      --project=$(gcloud config get-value project)
  ```
  **Skipping note**: Skipped if cluster creation fails due to quota or permission issues

- [ ] T021 Get cluster credentials for kubectl access
  **Output**: kubectl configured to communicate with GKE cluster
  **PowerShell Commands**:
  ```powershell
  gcloud container clusters get-credentials flask-cluster `
      --region=us-central1 `
      --project=$(gcloud config get-value project)
  ```
  **Skipping note**: Skipped if credential retrieval fails or kubectl not installed

**Checkpoint**: GKE cluster ready - Can accept container deployments

---

## Phase 7: Kubernetes Manifests and Deployment (Milestone 4 continued)

**Goal**: Deploy Flask container to GKE with LoadBalancer service

**Independent Test**: Access external IP and verify "Hello, GCP" appears with 200 status

- [ ] T022 [P] Create GKE Deployment manifest in `deployment.yaml`
  **Output**: Kubernetes Deployment for Flask container
  **File Contents**:
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
          image: us-central1-docker.pkg.dev/PROJECT_ID/flask-repo/flask-app:latest
          ports:
          - containerPort: 8080
          resources:
            requests:
              cpu: "250m"
              memory: "512Mi"
  ```
  **PowerShell Command to replace PROJECT_ID**:
  ```powershell
  $PROJECT_ID = gcloud config get-value project
  (Get-Content deployment.yaml) -replace 'PROJECT_ID', $PROJECT_ID | Set-Content deployment.yaml
  ```
  **Skipping note**: Skipped if deployment.yaml already exists with proper configuration

- [ ] T023 [P] Create GKE LoadBalancer Service manifest in `service.yaml`
  **Output**: Kubernetes Service for external access
  **File Contents**:
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
  **Skipping note**: Skipped if service.yaml already exists with proper configuration

- [ ] T024 Apply Kubernetes manifests to cluster
  **Output**: Flask application deployed to GKE with external access
  **PowerShell Commands**:
  ```powershell
  kubectl apply -f deployment.yaml
  kubectl apply -f service.yaml
  ```
  **Skipping note**: Skipped if kubectl apply fails due to image not found or cluster issues

- [ ] T025 Retrieve Service external IP and verify deployment
  **Output**: External IP address and verification of 200 status
  **PowerShell Commands**:
  ```powershell
  # Wait for external IP assignment (2-5 minutes typical)
  Write-Host "Waiting for external IP assignment..."
  kubectl get service flask-app-service -w

  # Once IP is assigned, test the service
  $EXTERNAL_IP = kubectl get service flask-app-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
  Write-Host "External IP: $EXTERNAL_IP"

  # Test the service
  $response = Invoke-WebRequest -Uri "http://$EXTERNAL_IP" -TimeoutSec 10
  if ($response.StatusCode -eq 200 -and $response.Content -like "*Hello, GCP*") {
      Write-Host "✅ GKE deployment verified successfully"
  } else {
      Write-Host "❌ GKE deployment verification failed"
  }
  ```
  **Skipping note**: Skipped if external IP not assigned after 10 minutes or verification fails

**Checkpoint**: GKE deployment complete and verified - Flask app accessible via LoadBalancer IP

---

## Phase 8: Cloud Endpoints Configuration (Milestone 5 - Optional)

**Goal**: Deploy Cloud Endpoints ESPv2 for API proxy (high complexity - may skip)

**Independent Test**: Access Endpoints URL and verify API proxy functionality

- [ ] T026 [P] Create minimal OpenAPI specification in `openapi.yaml`
  **Output**: OpenAPI spec for pass-through proxy
  **File Contents**:
  ```yaml
  swagger: '2.0'
  info:
    title: Flask API
    version: 1.0.0
  host: PROJECT_ID.appspot.com
  schemes:
    - https
  paths:
    /api/todos:
      get:
        summary: Get todos
        operationId: getTodos
        responses:
          '200':
            description: Success
      post:
        summary: Create todo
        operationId: createTodo
        responses:
          '201':
            description: Created
  ```
  **PowerShell Command to replace PROJECT_ID**:
  ```powershell
  $PROJECT_ID = gcloud config get-value project
  (Get-Content openapi.yaml) -replace 'PROJECT_ID', $PROJECT_ID | Set-Content openapi.yaml
  ```
  **Skipping note**: Skipped if OpenAPI spec already exists or if Endpoints complexity triggers Fast-Fail

- [ ] T027 Deploy Cloud Endpoints service configuration
  **Output**: Endpoints service deployed and ready
  **PowerShell Commands**:
  ```powershell
  gcloud endpoints services deploy openapi.yaml
  ```
  **Skipping note**: Skipped if Endpoints deployment takes >15 minutes or fails (Fast-Fail criteria)

- [ ] T028 Deploy ESPv2 Cloud Run service for proxy
  **Output**: ESPv2 proxy routing to App Engine
  **PowerShell Commands**:
  ```powershell
  $PROJECT_ID = gcloud config get-value project
  gcloud run deploy espv2 `
      --image="gcr.io/endpoints-release/endpoints-runtime:2" `
      --platform=managed `
      --allow-unauthenticated `
      --region=us-central1 `
      --set-env-vars="ESPv2_ARGS=--service=flask-api.endpoints.$PROJECT_ID.cloud.goog --rollout_strategy=managed --backend=https://$PROJECT_ID.appspot.com"
  ```
  **Skipping note**: Skipped if ESPv2 deployment fails or becomes too complex

**Checkpoint**: Cloud Endpoints proxy deployed (if not skipped due to complexity)

---

## Phase 9: Integration Testing and Documentation (Milestone 6)

**Goal**: Complete smoke tests and document deployment mapping

**Independent Test**: Run smoke test suite and verify all deployed services

- [ ] T029 [P] Run smoke test suite against all deployed services
  **Output**: pytest results showing homepage accessibility
  **PowerShell Commands**:
  ```powershell
  # Install test dependencies
  pip install pytest requests

  # Run smoke tests
  pytest tests/test_smoke.py -v

  # Test API endpoints manually
  $PROJECT_ID = gcloud config get-value project

  # Test App Engine API
  Write-Host "Testing App Engine API..."
  $response = Invoke-RestMethod -Uri "https://$PROJECT_ID.appspot.com/api/todos" -Method Get
  Write-Host "✅ GET /api/todos: $($response | ConvertTo-Json)"

  $response = Invoke-RestMethod -Uri "https://$PROJECT_ID.appspot.com/api/todos" -Method Post -ContentType "application/json" -Body '{"text":"Test from smoke test"}'
  Write-Host "✅ POST /api/todos: $($response | ConvertTo-Json)"
  ```
  **Skipping note**: Skipped if smoke tests fail or services are not accessible

- [ ] T030 Update README.md with deployment mapping and skip documentation
  **Output**: Complete README with service URLs and skip reasons
  **File Contents Template**:
  ```markdown
  # GCP Midterm: Minimal Flask App Deployment

  ## Deployment Status

  ✅ **App Engine**: https://your-project.appspot.com
  ✅ **Cloud Function**: https://us-central1-your-project.cloudfunctions.net/notify
  ✅ **GKE LoadBalancer**: http://[EXTERNAL-IP]
  ⚠️ **Cloud Endpoints**: [URL or SKIPPED]

  ## Assignment Mapping

  | Requirement | Status | Proof |
  |-------------|--------|-------|
  | Flask application | ✅ Complete | app/main.py with routes |
  | App Engine deployment | ✅ Complete | https://your-project.appspot.com |
  | Cloud Function v2 | ✅ Complete | Function deployed and tested |
  | GKE Autopilot deployment | ✅ Complete | LoadBalancer IP accessible |
  | Containerization | ✅ Complete | Image in Artifact Registry |
  | Smoke tests | ✅ Complete | pytest test_smoke.py passes |

  ## Skips (Intentional)

  ### Cloud Endpoints ESPv2
  - **What was skipped**: ESPv2 proxy deployment
  - **Why skipped**: High complexity, >15 minute setup time (Fast-Fail policy)
  - **How to complete later**: Deploy openapi.yaml with `gcloud endpoints services deploy`, then deploy ESPv2 with Cloud Run

  ## How to Test

  ### Homepage
  ```bash
  curl https://your-project.appspot.com
  # Should return: <html><body><h1>Hello, GCP</h1></body></html>
  ```

  ### Todo API
  ```bash
  # Get todos
  curl https://your-project.appspot.com/api/todos

  # Add todo
  curl -X POST https://your-project.appspot.com/api/todos -H "Content-Type: application/json" -d '{"text":"Buy milk"}'
  ```
  ```
  **Skipping note**: Skipped if README already contains complete deployment information

**Checkpoint**: All deployment artifacts documented and tested - Project complete

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all deployments
- **Deployment Phases (3-9)**: Sequential in milestone order (M1→M2→M3→M4→M5→M6)
- **Optional Phase (8)**: Cloud Endpoints can be skipped independently

### Within Each Phase

- All tasks marked [P] can run in parallel within their phase
- Container build (T018) depends on Dockerfile (T015) and repository (T017)
- GKE deployment (T024) depends on manifests (T022, T023) and cluster (T020)
- Manifest placeholder replacement must happen before kubectl apply

### Parallel Opportunities

- **Setup Phase**: T001 and T002 can run in parallel
- **Foundational Phase**: T003, T004, T005, T006 can run in parallel
- **Cloud Function Phase**: T011 and T012 can run in parallel
- **Container Phase**: T015 and T016 can run in parallel (T018 depends on both)
- **GKE Phase**: T022 and T023 can run in parallel
- **Testing Phase**: T029 can run in parallel with documentation (T030)

---

## Implementation Strategy

### MVP First (App Engine Only)

1. Complete Phase 1: Setup (T001-T002)
2. Complete Phase 2: Foundational (T003-T006) - CRITICAL
3. Complete Phase 3: App Engine Deployment (T007-T010)
4. **STOP and VALIDATE**: Test homepage and API at https://your-project.appspot.com
5. Demo MVP if ready

### Incremental Delivery (All Milestones)

1. **M1**: Add App Engine deployment → Test and demo
2. **M2**: Add Cloud Function → Test and demo
3. **M3**: Add container build → Verify Artifact Registry
4. **M4**: Add GKE deployment → Test LoadBalancer IP
5. **M5**: Add Cloud Endpoints (optional, may skip)
6. **M6**: Add testing and documentation → Complete project

### Fast-Fail Strategy

- **Cloud Endpoints**: Skip entire Phase 8 if >15 minutes setup time
- **GKE IP Issues**: Skip T025 verification if no external IP after 10 minutes
- **Cloud Function IAM**: Use `--allow-unauthenticated` flag to avoid permission issues
- **Container Build**: Revert to App Engine only if build/push fails

---

## Notes

- **PowerShell Compatibility**: All commands tested for Windows PowerShell environment
- **File Paths**: All paths are relative to repository root
- **Environment Variables**: PROJECT_ID automatically retrieved from gcloud config
- **Timeout Expectations**: GKE external IP assignment: 2-5 minutes, may take longer
- **Skip Documentation**: Each task includes clear skip reason for README documentation
- **Fast-Fail Policy**: Complex components (Endpoints) have clear skip criteria
- **Verification**: Each milestone includes verification steps to ensure success