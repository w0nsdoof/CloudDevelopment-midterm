<!-- Sync Impact Report:
Version change: 0.0.0 → 1.0.0 (initial adoption)
Modified principles: None (new constitution)
Added sections: All sections newly created based on project requirements
Removed sections: None (initial constitution)
Templates requiring updates:
- ✅ plan-template.md (Constitution Check section updated)
- ✅ spec-template.md (already aligned with minimal requirements)
- ✅ tasks-template.md (already aligned with MVP-first approach)
Follow-up TODOs: None
-->

# GCP Midterm Minimal App Constitution

## Core Principles

### I. Absolute Simplicity (NON-NEGOTIABLE)
Every implementation choice must favor the absolute simplest working solution that satisfies assignment checkboxes. No databases, no auth, no fancy features unless explicitly required by the assignment. Single region, single replica, default configurations whenever possible.

### II. MVP-First Delivery
Each GCP service deployment (App Engine, Cloud Functions, GKE, Endpoints) must be independently testable and provide immediate value. If a service integration becomes complex, skip it and document the reason clearly in README under "Skips (Intentional)".

### III. Windows/PowerShell Native
All commands and scripts must work in Windows PowerShell environment. No bash-only solutions. Use gcloud CLI defaults and avoid complex shell scripting.

### IV. Assignment-Checkbox Driven
Every deliverable must map directly to a specific requirement from requirements.md. README must contain explicit mapping table: "Assignment Requirement → Proof of Completion OR Skip Explanation".

### V. Fast-Fail Policy
If any step takes more than 15 minutes or requires complex debugging, immediately skip and document. The goal is working demos, not perfect implementations. All skips must be documented with clear "how to complete later" instructions.

## Technical Constraints

**Technology Stack**: Python 3.11 + Flask mandatory. No alternative languages or frameworks allowed.
**Infrastructure**: GCP services only. No AWS, Azure, or hybrid solutions.
**Runtime Target**: Public demo only. No PII, no authentication, no production security considerations.
**Operational**: Basic GCP console monitoring only. No custom dashboards, no SLOs, no alerting.
**Regional**: Single region deployment using gcloud defaults.

## Development Workflow

**Skip Documentation**: Every skipped step must be documented in README.md under "Skips (Intentional)" section with:
- What was skipped
- Why it was skipped (complexity/time constraint)
- How to complete it later (clear instructions)

**Proof of Completion**: For each GCP service, provide:
- Public URL where service is reachable
- Screenshot or curl command showing 200 OK response
- Brief description of what the service demonstrates

**Code Quality**: Minimal but functional. Basic error handling OK. No comprehensive testing required beyond basic unit tests.

## Governance

This constitution supersedes all technical discussions and implementation decisions. All development choices must be justified against these principles. When in doubt, choose the simpler option and document the skip.

**Amendment Process**: Changes require updating this constitution file and incrementing version number. All dependent templates must be reviewed for alignment.

**Compliance**: Before any deployment, verify against the assignment requirements mapping in README. If a deployment doesn't directly support a checkbox, reconsider or skip it.

**Version**: 1.0.0 | **Ratified**: 2025-10-15 | **Last Amended**: 2025-10-15