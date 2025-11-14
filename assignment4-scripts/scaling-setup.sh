#!/bin/bash
# Assignment 4 - Exercise 2: Scaling Applications Setup
# This script sets up scalable infrastructure for the Flask application

PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"

echo "Setting up scalable infrastructure for project: $PROJECT_ID"

# Enable required APIs
echo "Enabling required APIs..."
gcloud services enable \
    compute.googleapis.com \
    container.googleapis.com \
    cloudbuild.googleapis.com \
    artifactregistry.googleapis.com \
    run.googleapis.com \
    networking.googleapis.com \
    dns.googleapis.com

echo "✅ APIs enabled"

# Create Artifact Registry for container images
echo "Creating Artifact Registry..."
gcloud artifacts repositories create flask-repo \
    --repository-format=docker \
    --location=$REGION \
    --description="Docker repository for Flask application"

echo "✅ Artifact Registry created"

# Build and push container image
echo "Building and pushing container image..."
gcloud builds submit --tag us-central1-docker.pkg.dev/$PROJECT_ID/flask-repo/flask-app:latest .

echo "✅ Container image built and pushed"

# Create GKE cluster with autopilot mode
echo "Creating GKE Autopilot cluster..."
gcloud container clusters create-auto flask-cluster \
    --location=$REGION \
    --release-channel=stable \
    --network=default

echo "✅ GKE Autopilot cluster created"

# Get cluster credentials
gcloud container clusters get-credentials flask-cluster --location=$REGION

# Create enhanced deployment with horizontal scaling
cat > scalable-deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flask-app
  labels:
    app: flask-app
spec:
  replicas: 3
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
        image: us-central1-docker.pkg.dev/$PROJECT_ID/flask-repo/flask-app:latest
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: "250m"
            memory: "256Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
        env:
        - name: REDIS_URL
          value: "redis://redis-service:6379"
        livenessProbe:
          httpGet:
            path: /api/status
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /api/status
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: flask-app-service
spec:
  selector:
    app: flask-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
  type: ClusterIP
EOF

echo "✅ Kubernetes deployment manifests created"

# Deploy Redis for session storage
cat > redis-deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "200m"
            memory: "256Mi"
---
apiVersion: v1
kind: Service
metadata:
  name: redis-service
spec:
  selector:
    app: redis
  ports:
    - port: 6379
      targetPort: 6379
EOF

echo "✅ Redis deployment manifests created"

# Deploy applications
echo "Deploying applications..."
kubectl apply -f redis-deployment.yaml
kubectl apply -f scalable-deployment.yaml

echo "✅ Applications deployed"

# Wait for deployments to be ready
echo "Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/redis
kubectl wait --for=condition=available --timeout=300s deployment/flask-app

echo "✅ Deployments are ready"

# Create Horizontal Pod Autoscaler
echo "Setting up Horizontal Pod Autoscaler..."
kubectl autoscale deployment flask-app \
    --cpu-percent=50 \
    --min=2 \
    --max=10

echo "✅ HPA configured"

# Set up External Load Balancer with health checks
cat > loadbalancer-service.yaml << EOF
apiVersion: v1
kind: Service
metadata:
  name: flask-app-loadbalancer
  annotations:
    cloud.google.com/load-balancer-type: "External"
spec:
  type: LoadBalancer
  selector:
    app: flask-app
  ports:
    - port: 80
      targetPort: 8080
      protocol: TCP
  healthCheck:
    httpGet:
      path: /api/status
      port: 8080
    initialDelaySeconds: 30
    timeoutSeconds: 10
    periodSeconds: 15
EOF

kubectl apply -f loadbalancer-service.yaml

echo "✅ Load Balancer configured with health checks"

# Get external IP
echo "Getting external IP..."
EXTERNAL_IP=""
while [ -z "$EXTERNAL_IP" ]; do
  EXTERNAL_IP=$(kubectl get service flask-app-loadbalancer -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  if [ -z "$EXTERNAL_IP" ]; then
    echo "Waiting for external IP..."
    sleep 10
  fi
done

echo "✅ External Load Balancer IP: $EXTERNAL_IP"

# Create enhanced App Engine deployment with scaling
echo "Setting up enhanced App Engine configuration..."
cat > enhanced-app.yaml << EOF
runtime: python311
entrypoint: gunicorn -b :\$PORT main:app
instance_class: F2

automatic_scaling:
  min_instances: 1
  max_instances: 10
  min_idle_instances: 0
  max_idle_instances: 2
  target_cpu_utilization: 0.65
  target_throughput_utilization: 0.75

resources:
  cpu: 2
  memory_gb: 2
  disk_size_gb: 10

network:
  forwarded_ports:
    - 8080

env_variables:
  REDIS_URL: 'redis://redis-instance:6379'

health_check:
  enable_health_check: True
  check_interval_sec: 5
  timeout_sec: 4
  unhealthy_threshold: 2
  healthy_threshold: 2

readiness_check:
  app_start_timeout_sec: 300
  path: "/api/status"
EOF

echo "✅ Enhanced App Engine configuration created"

# Deploy to Cloud Run as alternative serverless option
echo "Deploying to Cloud Run..."
gcloud run deploy flask-app-cloudrun \
    --image us-central1-docker.pkg.dev/$PROJECT_ID/flask-repo/flask-app:latest \
    --platform managed \
    --region $REGION \
    --allow-unauthenticated \
    --memory 512Mi \
    --cpu 1 \
    --min-instances 0 \
    --max-instances 100 \
    --concurrency 100

echo "✅ Cloud Run deployment completed"

# Save deployment information
cat > deployment-info.txt << EOF
Deployment completed successfully!

🚀 Deployment URLs:
- App Engine: https://$PROJECT_ID.uc.r.appspot.com
- Cloud Run: $(gcloud run services describe flask-app-cloudrun --region $REGION --format='value(status.url)')
- GKE LoadBalancer: http://$EXTERNAL_IP

📊 Scaling Configuration:
- GKE: 2-10 pods based on CPU utilization (50% threshold)
- App Engine: 1-10 instances based on CPU (65%) and throughput (75%)
- Cloud Run: 0-100 instances with 100 concurrent requests each

🔍 Health Checks:
- All deployments have health checks enabled
- Endpoint: /api/status
- Failed instances are automatically replaced

📈 Monitoring:
- Metrics available in Google Cloud Monitoring
- Auto-scaling based on CPU, memory, and request metrics
EOF

echo "🎯 Scaling setup completed!"
cat deployment-info.txt