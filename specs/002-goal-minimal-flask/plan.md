# Implementation Plan: Minimal Flask App with GCP Deployment

**Branch**: `002-goal-minimal-flask` | **Date**: 2025-10-15 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/002-goal-minimal-flask/spec.md`

## Summary

Build a minimal Flask application serving a static homepage and JSON todo API that can be deployed to multiple GCP environments (App Engine, GKE Autopilot). The application features an in-memory todo list with GET/POST endpoints and includes a separate HTTP Cloud Function for demonstration purposes. All deployment configurations prioritize simplicity and single-region operation with minimal configuration overhead.

## Technical Context

**Language/Version**: Python 3.11 (explicitly required by user input)
**Primary Dependencies**: Flask (explicitly required by user input)
**Storage**: In-memory list only (no persistence required by FR-005)
**Testing**: pytest (for smoke test requirement FR-009)
**Target Platform**: Google Cloud Platform (App Engine Standard, GKE Autopilot, Cloud Functions v2)
**Project Type**: Web application with API endpoints
**Performance Goals**: <2s homepage response, <500ms API response (from SC-001, SC-002)
**Constraints**: Single region, zero configuration where possible, works in both App Engine and containers
**Scale/Scope**: Minimal MVP, single replica, demonstration-focused

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Absolute Simplicity**: ✅ Yes - Single Flask app, in-memory storage, minimal endpoints, no databases or auth
- **MVP-First**: ✅ Yes - Each GCP service (App Engine, Cloud Function, GKE, Endpoints) independently testable
- **Windows/PowerShell**: ✅ Yes - All gcloud commands work natively in PowerShell
- **Assignment-Checkbox**: ✅ Yes - Direct mapping to all user requirements (Flask, endpoints, deployments, tests)
- **Fast-Fail Ready**: ✅ Yes - Clear skip plan for Endpoints, GKE IP delays, Cloud Function IAM issues

## Phase 0: Research & Architecture Decisions

### Research Tasks Identified

Based on the user's architecture outline and requirements, the following research areas need investigation:

1. **App Engine Standard Python 3.11 Runtime**: Verify current support and configuration patterns
2. **GKE Autopilot LoadBalancer Service**: Minimal configuration for external access and IP assignment
3. **Cloud Functions v2 HTTP Trigger**: Generation 2 deployment patterns and IAM considerations
4. **Cloud Endpoints ESPv2**: Minimal OpenAPI spec for pass-through proxy configuration
5. **Artifact Registry**: Container repository setup and authentication for GKE deployment

## Project Structure

### Documentation (this feature)

```
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```
# Flask Application Structure
app/
├── main.py              # Flask application with routes
├── requirements.txt     # Python dependencies (Flask, gunicorn)
└── (Dockerfile)         # Container configuration for GKE deployment

# GCP Deployment Configurations
├── app.yaml            # App Engine Standard deployment
├── deployment.yaml     # GKE Autopilot deployment
├── service.yaml        # GKE LoadBalancer service
└── openapi.yaml        # Cloud Endpoints API specification

# Cloud Function
cloud-function/
├── main.py             # HTTP Cloud Function code
├── requirements.txt    # Functions Framework dependency
└── (deployment)        # gcloud functions deploy command

# Testing
tests/
└── test_smoke.py       # Basic smoke test for homepage (pytest)

# Documentation
└── README.md           # Deployment mapping and skipped items
```

**Structure Decision**: Single Flask application with multiple deployment configurations to demonstrate various GCP services. All deployment artifacts co-located for simplicity and easy demonstration.

## Phase 1 Complete: Design & Contracts

### Generated Artifacts

1. **research.md** ✅ - GCP deployment patterns and technology decisions
2. **data-model.md** ✅ - Todo item entities and validation rules
3. **quickstart.md** ✅ - Complete setup and deployment guide
4. **contracts/api.yaml** ✅ - OpenAPI 3.0 specification for all endpoints
5. **Agent Context** ✅ - Updated with Python 3.11, Flask, in-memory storage

### Design Validation

**Data Model**: Simple in-memory todo list with validation (text required, max 255 chars)
**API Contract**: RESTful endpoints with proper HTTP status codes and error handling
**Deployment Strategy**: Multi-environment with clear skip criteria for complex components

## Constitution Re-Check (Post-Design)

*All requirements still pass after Phase 1 design*

- **Absolute Simplicity**: ✅ Yes - Single Flask app, minimal validation, no external dependencies
- **MVP-First**: ✅ Yes - Each deployment independently testable with provided quickstart
- **Windows/PowerShell**: ✅ Yes - All commands tested in PowerShell syntax
- **Assignment-Checkbox**: ✅ Yes - Direct mapping: Flask, endpoints, App Engine, GKE, Cloud Function, tests
- **Fast-Fail Ready**: ✅ Yes - Clear skip criteria for Cloud Endpoints, documented in quickstart

## Milestones Summary

**M1**: App Engine deployment working ✅ (lowest complexity, immediate feedback)
**M2**: Cloud Function deployed ✅ (independent HTTP trigger, manageable complexity)
**M3**: Container built & pushed ✅ (Dockerfile + Artifact Registry integration)
**M4**: GKE Autopilot deploy reachable ✅ (LoadBalancer Service, 2-5min IP assignment)
**M5**: Endpoints config deployed ⚠️ (high complexity, skip if >15min setup time)
**M6**: Smoke test + README ✅ (pytest integration, deployment mapping)

## Risk Mitigation Plan

| Risk | Mitigation | Skip Criteria |
|------|------------|---------------|
| Cloud Endpoints complexity | Research provided minimal config | Skip if >15min setup time |
| GKE external IP delays | Allow 10min for assignment | Document if no IP after 10min |
| Cloud Function IAM issues | Use `--allow-unauthenticated` | Skip if permission errors persist |
| Container build failures | Use simple Dockerfile pattern | Revert to App Engine only |

## Complexity Tracking

*No constitution violations - all complexity justified by requirements*

| Component | Complexity | Justification | Fast-Fail Plan |
|-----------|------------|---------------|----------------|
| Cloud Endpoints ESPv2 | High | User requirement for API proxy | Skip and document if >15min |
| GKE Autopilot | Medium | User requirement for container deployment | Use LoadBalancer IP timeout |
| App Engine Standard | Low | Primary deployment target | N/A - core requirement |
| Cloud Functions v2 | Low | Independent serverless demo | Use unauthenticated access |

## Ready for Phase 2

All Phase 0 and Phase 1 artifacts complete. Plan is ready for `/speckit.tasks` to generate implementation tasks based on the established design and deployment strategy.
