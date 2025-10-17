# Feature Specification: Minimal Flask App with GCP Deployment

**Feature Branch**: `002-goal-minimal-flask`
**Created**: 2025-10-15
**Status**: Draft
**Input**: User description: "Goal: Minimal Flask app with one static homepage (/) and one JSON endpoint (/api/todos) backed by in-memory list. Actors: - Visitor: views homepage. - Client: GET/POST todos. Functional Requirements: 1) GET / returns simple HTML "Hello, GCP". 2) GET /api/todos returns JSON list. 3) POST /api/todos accepts JSON {text} and appends to in-memory list; returns 201 and count. 4) No persistence; restart clears list. Non-Functional: - Python 3.11; Flask. - Single region; zero config where possible. - Works on App Engine and inside a container for GKE. Deliverables: - App Engine deployment (app.yaml). - One HTTP Cloud Function "notify" (no integration required). - Dockerfile and GKE Autopilot deployment (1 replica, LoadBalancer Service). - Minimal Cloud Endpoints (ESPv2) pass-through for /api/todos to App Engine URL. - One pytest smoke test (status 200 on "/"). - README that lists any skipped parts. Acceptance Tests (GWT): - Given the app is deployed to App Engine, when I visit "/", then I see 200"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View Static Homepage (Priority: P1)

As a visitor to the website, I want to see a simple greeting page so that I can confirm the application is running and accessible.

**Why this priority**: This is the most basic functionality required to verify the application deployment works correctly. It provides immediate feedback to users that the service is operational.

**Independent Test**: Can be fully tested by accessing the root URL "/" and verifying the response contains "Hello, GCP" with a 200 status code. This delivers the core value of confirming the application is running.

**Acceptance Scenarios**:

1. **Given** the application is deployed to App Engine, **When** a visitor accesses the root URL "/", **Then** they receive a 200 status code and see "Hello, GCP" in the HTML response
2. **Given** the application is running in a GKE container, **When** a visitor accesses the root URL "/", **Then** they receive a 200 status code and see "Hello, GCP" in the HTML response

---

### User Story 2 - Manage Todo Items (Priority: P1)

As a client application, I want to retrieve and add todo items through a JSON API so that I can manage a simple todo list.

**Why this priority**: This is the core functionality that provides value beyond a static homepage. It demonstrates the application's ability to handle data operations and serve both human visitors and programmatic clients.

**Independent Test**: Can be fully tested by making GET and POST requests to "/api/todos" endpoint and verifying the JSON responses and list management behavior. This delivers the value of a functional todo management system.

**Acceptance Scenarios**:

1. **Given** the application is running with an empty todo list, **When** a client sends a GET request to "/api/todos", **Then** they receive a 200 status code and an empty JSON array
2. **Given** the application is running, **When** a client sends a POST request to "/api/todos" with JSON {"text": "Buy milk"}, **Then** they receive a 201 status code and the current count of todo items
3. **Given** one todo item exists, **When** a client sends a GET request to "/api/todos", **Then** they receive a 200 status code and a JSON array containing the previously added todo item

---

### User Story 3 - Cloud Function Notification (Priority: P2)

As a system administrator, I want a separate HTTP Cloud Function for notifications so that I can demonstrate serverless computing capabilities alongside the main application.

**Why this priority**: This showcases GCP's serverless capabilities and provides a separate deployment artifact for cloud function demonstration, though it's not integrated with the main application functionality.

**Independent Test**: Can be fully tested by invoking the "notify" Cloud Function directly and verifying it responds appropriately. This delivers the value of demonstrating serverless function deployment.

**Acceptance Scenarios**:

1. **Given** the Cloud Function "notify" is deployed, **When** an HTTP request is made to its endpoint, **Then** the function executes successfully and returns an appropriate response

---

### Edge Cases

- What happens when the todo list becomes very large (performance implications)?
- How does the system handle invalid JSON in POST requests to /api/todos?
- What happens when the POST request is missing the "text" field?
- How does the system handle concurrent requests to modify the todo list?
- What happens when the application restarts - is the todo list properly cleared?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Application MUST serve a static HTML page at root path "/" displaying "Hello, GCP"
- **FR-002**: Application MUST provide a GET endpoint at "/api/todos" that returns the current todo list as JSON
- **FR-003**: Application MUST provide a POST endpoint at "/api/todos" that accepts JSON with a "text" field and adds it to the todo list
- **FR-004**: POST requests to "/api/todos" MUST return HTTP status 201 and the current count of todo items
- **FR-005**: Todo list MUST be stored in memory only and MUST be cleared when the application restarts
- **FR-006**: Application MUST be deployable to both App Engine and GKE Autopilot environments
- **FR-007**: A separate HTTP Cloud Function named "notify" MUST be deployable independently
- **FR-008**: Cloud Endpoints (ESPv2) MUST provide pass-through routing for "/api/todos" to the App Engine URL
- **FR-009**: Application MUST include automated smoke tests verifying the root path returns 200 status
- **FR-010**: Deployment configurations MUST support single-region deployment with minimal configuration

### Key Entities *(include if feature involves data)*

- **Todo Item**: Represents a single task with text content. Key attributes: text (string). No persistence required.
- **Todo List**: An in-memory collection of todo items. Automatically cleared on application restart.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can access the homepage and see "Hello, GCP" within 2 seconds of request
- **SC-002**: API clients can retrieve the complete todo list in under 500 milliseconds
- **SC-003**: New todo items can be added successfully with 100% success rate for valid requests
- **SC-004**: Application can be deployed to both App Engine and GKE environments using provided configurations
- **SC-005**: Automated smoke tests pass consistently, confirming homepage accessibility
- **SC-006**: Cloud Endpoints successfully route API traffic to the App Engine application
- **SC-007**: Application restarts result in completely cleared todo lists (no data persistence)