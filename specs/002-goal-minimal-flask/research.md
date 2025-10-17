# Research Findings: Minimal Flask App with GCP Deployment

**Date**: 2025-10-15
**Research Focus**: GCP deployment patterns for Flask application

## Architecture Decisions

### Decision: Multi-environment Flask deployment
**Rationale**: User explicitly requires deployment to both App Engine Standard and GKE Autopilot to demonstrate containerization capabilities
**Alternatives considered**: Single deployment target (rejected per requirements)

### Decision: In-memory data storage
**Rationale**: FR-005 explicitly requires no persistence and clear list on restart
**Alternatives considered**: Cloud Firestore, Cloud SQL (rejected as over-complex)

## Technology Research Results

### 1. App Engine Standard Python 3.11 Runtime

**Decision**: Use Python 3.11 runtime with Gunicorn entrypoint
**Rationale**: Python 3.11 is fully supported, Gunicorn provides production-ready WSGI server
**Key Configuration**:
```yaml
runtime: python311
entrypoint: gunicorn -b :$PORT main:app
instance_class: F1
automatic_scaling:
  min_instances: 0
  max_instances: 1
```

**Common Pitfalls Identified**:
- Missing entrypoint causes deployment failures
- Must use `$PORT` environment variable, not hardcoded ports
- Ensure Flask app is named `app` in main.py

### 2. GKE Autopilot LoadBalancer Service

**Decision**: Use minimal Deployment + LoadBalancer Service configuration
**Rationale**: Autopilot simplifies cluster management, LoadBalancer provides external access
**Key Configuration**:
- Single replica deployment with 250m CPU, 512Mi memory requests
- LoadBalancer Service targeting port 80 (external) to 8080 (container)
- External IP assignment typically takes 2-5 minutes

**Potential Delays**: External IP assignment may show `<pending>` for up to 5 minutes
**Fast-Fail Trigger**: If IP not assigned after 10 minutes, document and skip

### 3. Cloud Functions v2 HTTP Trigger

**Decision**: Deploy independent HTTP Cloud Function named "notify"
**Rationale**: Demonstrates serverless capabilities, Gen2 provides better performance
**Key Configuration**:
```python
import functions_framework

@functions_framework.http
def notify(request):
    return {"message": "Notification sent"}, 200
```

**IAM Considerations**: Use `--allow-unauthenticated` flag for public access
**Complexity**: Medium - requires separate deployment but manageable

### 4. Cloud Endpoints ESPv2

**Decision**: Plan for pass-through proxy but expect potential skip
**Rationale**: High complexity with multiple moving parts (OpenAPI spec, ESPv2 config, IAM)
**Fast-Fail Ready**: Marked as likely skip if deployment becomes complex
**Alternative**: Direct App Engine access or API Gateway

### 5. Artifact Registry

**Decision**: Use Docker repository for container images
**Rationale**: Required for GKE deployment, provides secure storage
**Key Configuration**:
- Repository format: Docker
- Location: us-central1 (GCP default)
- Authentication via gcloud CLI

**Build Process**: Docker build → Tag → Push to Artifact Registry → Deploy to GKE

## Deployment Strategy

### Recommended Order (based on complexity):
1. **M1**: App Engine deployment (lowest complexity, immediate feedback)
2. **M2**: Cloud Function deployment (medium complexity, independent)
3. **M3**: Container build and Artifact Registry push (required for GKE)
4. **M4**: GKE Autopilot deployment (higher complexity, requires container)
5. **M5**: Cloud Endpoints ESPv2 (highest complexity, likely skip)
6. **M6**: Integration testing and documentation

### Risk Mitigation:
- **Cloud Endpoints complexity**: Plan to skip and document if ESPv2 setup takes >15 minutes
- **GKE IP delays**: Allow up to 10 minutes for external IP assignment
- **Cloud Function IAM**: Use `--allow-unauthenticated` to avoid permission issues

## Performance Expectations

Based on research and requirements:
- **Homepage response**: <2 seconds (achievable with App Engine Standard)
- **API response**: <500ms (realistic for in-memory operations)
- **Cold starts**: App Engine may have 2-5 second cold starts
- **Concurrent handling**: Single replica adequate for demonstration purposes

## PowerShell Compatibility

All researched commands are confirmed to work in PowerShell environment:
- `gcloud` commands use PowerShell syntax for line continuation (`backtick`)
- `kubectl` commands compatible with PowerShell
- Docker commands work natively in PowerShell

## Success Criteria Mapping

Research confirms all success criteria are achievable:
- **SC-001**: <2s homepage response ✅ (App Engine Standard)
- **SC-002**: <500ms API response ✅ (In-memory operations)
- **SC-003**: 100% success rate ✅ (Simple POST endpoint)
- **SC-004**: Multi-environment deployment ✅ (App Engine + GKE)
- **SC-005**: Automated testing ✅ (pytest smoke test)
- **SC-006**: Endpoints routing ⚠️ (Complex, may skip)
- **SC-007**: No persistence ✅ (In-memory list)

## Next Steps

Proceed to Phase 1 design with confidence that:
- All technical requirements are achievable
- Risk areas are identified with mitigation strategies
- PowerShell-compatible deployment patterns are established
- Fast-fail criteria are defined for complex components