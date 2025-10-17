# Quickstart Guide: Minimal Flask App with GCP Deployment

**Purpose**: Get the Flask application running locally and deployed to GCP services
**Prerequisites**: gcloud CLI, Docker, kubectl, Python 3.11

## Local Development Setup

### 1. Install Dependencies
```powershell
# Create virtual environment
python -m venv venv
venv\Scripts\Activate.ps1

# Install Python packages
pip install flask gunicorn pytest requests
```

### 2. Create Flask Application
Create `app/main.py`:
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

Create `app/requirements.txt`:
```
flask==3.0.0
gunicorn==21.2.0
```

### 3. Run Locally
```powershell
cd app
python main.py
```

Test the application:
```powershell
# Test homepage
curl http://localhost:8080

# Test API
curl http://localhost:8080/api/todos
curl -X POST http://localhost:8080/api/todos -H "Content-Type: application/json" -d '{"text":"Buy milk"}'
```

## GCP Deployment

### 1. Setup GCP Project
```powershell
# Set your project ID
$PROJECT_ID = "your-project-id"
gcloud config set project $PROJECT_ID

# Enable required APIs
gcloud services enable appengine.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable container.googleapis.com
gcloud services enable run.googleapis.com
```

### 2. Deploy to App Engine (Milestone 1)
Create `app.yaml`:
```yaml
runtime: python311
entrypoint: gunicorn -b :$PORT main:app
instance_class: F1
automatic_scaling:
  min_instances: 0
  max_instances: 1
```

Deploy:
```powershell
cd app
gcloud app deploy
```

### 3. Deploy Cloud Function (Milestone 2)
Create `cloud-function/main.py`:
```python
import functions_framework

@functions_framework.http
def notify(request):
    return {"message": "Notification sent from Cloud Function", "timestamp": "2025-10-15"}, 200
```

Create `cloud-function/requirements.txt`:
```
functions-framework==3.*
```

Deploy:
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

### 4. Build and Deploy to GKE (Milestones 3-4)
Create `Dockerfile`:
```dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

EXPOSE 8080
CMD ["gunicorn", "-b", "0.0.0.0:8080", "main:app"]
```

Create `deployment.yaml`:
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
        image: us-central1-docker.pkg.dev/your-project/flask-repo/flask-app:latest
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: "250m"
            memory: "512Mi"
```

Create `service.yaml`:
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

Deploy to GKE:
```powershell
# Create Artifact Registry repository
gcloud artifacts repositories create flask-repo `
    --repository-format=docker `
    --location=us-central1

# Build and push container
docker build -t us-central1-docker.pkg.dev/$PROJECT_ID/flask-repo/flask-app:latest .
gcloud auth configure-docker us-central1-docker.pkg.dev
docker push us-central1-docker.pkg.dev/$PROJECT_ID/flask-repo/flask-app:latest

# Create GKE cluster
gcloud container clusters create-auto flask-cluster `
    --region=us-central1

# Deploy application
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml

# Get external IP
kubectl get service flask-app-service -w
```

### 5. Cloud Endpoints (Milestone 5 - Optional)
Create `openapi.yaml`:
```yaml
swagger: '2.0'
info:
  title: Flask API
  version: 1.0.0
host: $PROJECT_ID.appspot.com
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

Deploy (if time permits):
```powershell
gcloud endpoints services deploy openapi.yaml
gcloud run deploy espv2 `
    --image="gcr.io/endpoints-release/endpoints-runtime:2" `
    --platform=managed `
    --allow-unauthenticated `
    --set-env-vars="ESPv2_ARGS=--service=flask-api.endpoints.$PROJECT_ID.cloud.goog --rollout_strategy=managed --backend=https://$PROJECT_ID.appspot.com"
```

## Testing (Milestone 6)

### Smoke Test
Create `tests/test_smoke.py`:
```python
import requests
import pytest

def test_homepage():
    """Test that homepage returns 200 status"""
    response = requests.get('https://your-project.appspot.com', timeout=10)
    assert response.status_code == 200
    assert 'Hello, GCP' in response.text

def test_api_endpoints():
    """Test API endpoints"""
    base_url = 'https://your-project.appspot.com/api'

    # Test GET todos
    response = requests.get(f'{base_url}/todos', timeout=10)
    assert response.status_code == 200
    assert isinstance(response.json(), list)

    # Test POST todo
    response = requests.post(f'{base_url}/todos',
                           json={'text': 'Test item'},
                           timeout=10)
    assert response.status_code == 201
    assert 'count' in response.json()
```

Run tests:
```powershell
pytest tests/test_smoke.py -v
```

## Common Issues and Solutions

### App Engine Issues
- **Deployment fails**: Check that `main.py` exists and Flask app is named `app`
- **Port errors**: Ensure you're using `$PORT` environment variable, not hardcoded 8080

### GKE Issues
- **Image pull errors**: Verify Artifact Registry permissions and image path
- **External IP pending**: Wait 5-10 minutes for LoadBalancer IP assignment
- **Pod crashes**: Check container logs with `kubectl logs deployment/flask-app`

### Cloud Function Issues
- **Permission denied**: Use `--allow-unauthenticated` flag for public access
- **Gen2 deployment**: Ensure `--gen2` flag is included

## URLs and Verification

After deployment, verify each service:

- **App Engine**: https://your-project.appspot.com
- **Cloud Function**: https://us-central1-your-project.cloudfunctions.net/notify
- **GKE LoadBalancer**: http://[EXTERNAL-IP] (from `kubectl get service`)
- **Cloud Endpoints**: https://flask-api.endpoints.your-project.cloud.goog (if deployed)

Each should return appropriate responses as defined in the API contract.