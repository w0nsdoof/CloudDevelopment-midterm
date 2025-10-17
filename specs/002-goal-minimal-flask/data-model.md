# Data Model: Minimal Flask App

**Date**: 2025-10-15
**Based on**: [Feature Specification](spec.md)

## Entities

### Todo Item

**Purpose**: Represents a single task in the todo list
**Storage**: In-memory list (cleared on application restart)

**Attributes**:
- `text` (string, required): The task description
- `id` (integer, auto-generated): Unique identifier within the list
- `created_at` (timestamp, auto-generated): When the item was added

**Validation Rules**:
- `text` must be non-empty string
- `text` maximum length: 255 characters (reasonable limit)
- `id` is sequential starting from 1

### Todo List

**Purpose**: In-memory collection of todo items
**Storage**: Python list in application memory

**Operations**:
- `GET /api/todos`: Return all items as JSON array
- `POST /api/todos`: Add new item to list, return count

**State Transitions**:
- Empty list → Non-empty list (when first item added)
- Non-empty list → Empty list (when application restarts)

## Data Flow

### Add Todo Item (POST /api/todos)

1. **Request**: JSON `{ "text": "Buy milk" }`
2. **Validation**:
   - Check JSON is valid
   - Check `text` field exists and is non-empty
   - Check `text` length ≤ 255 characters
3. **Processing**:
   - Generate new `id` (current list length + 1)
   - Set `created_at` to current timestamp
   - Append to in-memory list
4. **Response**: HTTP 201 with `{ "count": 3 }`

### Get Todo List (GET /api/todos)

1. **Request**: No body required
2. **Processing**: Return current in-memory list as JSON
3. **Response**: HTTP 200 with JSON array of todo items

### Get Homepage (GET /)

1. **Request**: No body required
2. **Processing**: Serve static HTML
3. **Response**: HTTP 200 with HTML containing "Hello, GCP"

## Error Handling

### Validation Errors

- **Missing text field**: HTTP 400 with `{ "error": "text field is required" }`
- **Empty text**: HTTP 400 with `{ "error": "text cannot be empty" }`
- **Text too long**: HTTP 400 with `{ "error": "text maximum 255 characters" }`
- **Invalid JSON**: HTTP 400 with `{ "error": "invalid JSON" }`

### System Errors

- **Memory limits**: HTTP 500 with generic error message
- **Application crash**: Handled by GCP platform (App Engine/GKE)

## Performance Considerations

### Memory Usage
- **Per item**: ~50-100 bytes (text + metadata)
- **Maximum list size**: Limited by available memory
- **Expected usage**: <100 items for demonstration purposes

### Response Times
- **GET /api/todos**: <10ms (memory access)
- **POST /api/todos**: <10ms (list append)
- **GET /**: <5ms (static HTML)

## Scalability Notes

### Current Limitations
- **Single instance**: All requests handled by single process
- **Memory-only**: Data lost on restart
- **No persistence**: Cannot handle horizontal scaling

### Future Enhancements (not in scope)
- **Database storage**: Cloud Firestore or Cloud SQL
- **Caching**: Redis for performance
- **Load balancing**: Multiple instances for high availability

## Integration Points

### App Engine Integration
- **Runtime**: Python 3.11
- **Entry point**: Gunicorn WSGI server
- **Scaling**: Automatic scaling (0-1 instances)

### GKE Integration
- **Containerization**: Docker image with Python 3.11
- **Port**: 8080 (container) → 80 (external)
- **Health check**: Homepage endpoint for liveness/readiness

### Cloud Functions Integration
- **Independent service**: Separate from Flask app
- **HTTP trigger**: Public endpoint for notifications
- **No shared data**: Completely isolated from todo list