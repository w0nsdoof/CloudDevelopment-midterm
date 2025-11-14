from flask import Flask, jsonify, request
from datetime import datetime
import os
import json
import base64
from google.cloud import kms_v1
from google.cloud import monitoring_v3
from google.cloud import logging
import hashlib

app = Flask(__name__)

# Configuration
PROJECT_ID = os.environ.get('GOOGLE_CLOUD_PROJECT', 'gcp-as3-assignment')
LOCATION = os.environ.get('KMS_LOCATION', 'us-central1')
KEY_RING = os.environ.get('KMS_KEY_RING', 'flask-keyring')
KEY_ID = os.environ.get('KMS_KEY_ID', 'flask-encryption-key')

# Initialize Google Cloud clients
try:
    kms_client = kms_v1.KeyManagementServiceClient()
    logging_client = logging.Client()
    logger = logging_client.logger('flask-app-security')
    monitoring_client = monitoring_v3.MetricServiceClient()

    # Security features status
    KMS_ENABLED = True
    LOGGING_ENABLED = True
    MONITORING_ENABLED = True
except Exception as e:
    print(f"Security features disabled: {e}")
    KMS_ENABLED = False
    LOGGING_ENABLED = False
    MONITORING_ENABLED = False

# In-memory storage with encryption support
user_data = {}
todos = []

def log_security_event(event_type, details):
    """Log security events to Cloud Logging"""
    if not LOGGING_ENABLED:
        return

    try:
        logger.log_text(
            f"SECURITY_EVENT: {event_type}",
            severity="INFO",
            http_request={
                "requestMethod": request.method,
                "requestUrl": request.url,
                "userAgent": request.headers.get("User-Agent", ""),
                "remoteIp": request.remote_addr
            },
            json_payload=details
        )
    except Exception as e:
        print(f"Failed to log security event: {e}")

def record_metric(metric_type, value, labels=None):
    """Record custom metrics to Cloud Monitoring"""
    if not MONITORING_ENABLED:
        return

    try:
        series = monitoring_v3.TimeSeries()
        series.metric.type = f"custom.googleapis.com/flask_app/{metric_type}"
        series.resource.type = "gae_app"
        series.resource.labels["project_id"] = PROJECT_ID
        series.resource.labels["module_id"] = os.environ.get("GAE_MODULE_ID", "default")

        if labels:
            series.metric.labels.update(labels)

        point = series.points.add()
        point.value.double_value = value
        point.interval.end_time = {"seconds": int(datetime.utcnow().timestamp())}

        monitoring_client.create_time_series(name=f"projects/{PROJECT_ID}", time_series=[series])
    except Exception as e:
        print(f"Failed to record metric: {e}")

def encrypt_text(text):
    """Encrypt text using Cloud KMS"""
    if not KMS_ENABLED or not text:
        return text

    try:
        key_name = kms_client.crypto_key_path(PROJECT_ID, LOCATION, KEY_RING, KEY_ID)

        # Encrypt the text
        response = kms_client.encrypt(
            request={"name": key_name, "plaintext": text.encode("utf-8")}
        )

        # Return base64 encoded ciphertext
        return base64.b64encode(response.ciphertext).decode('utf-8')
    except Exception as e:
        print(f"Encryption failed, using plaintext: {e}")
        return text

def decrypt_text(ciphertext):
    """Decrypt text using Cloud KMS"""
    if not KMS_ENABLED or not ciphertext:
        return ciphertext

    try:
        # Check if it's base64 encoded (encrypted)
        try:
            decoded = base64.b64decode(ciphertext)
            key_name = kms_client.crypto_key_path(PROJECT_ID, LOCATION, KEY_RING, KEY_ID)

            response = kms_client.decrypt(
                request={"name": key_name, "ciphertext": decoded}
            )

            return response.plaintext.decode("utf-8")
        except:
            # Not encrypted, return as-is
            return ciphertext
    except Exception as e:
        print(f"Decryption failed, returning original: {e}")
        return ciphertext

def validate_todo_text(text):
    """Additional security validation for todo text"""
    if not text:
        return False, "Text cannot be empty"

    # Check for suspicious patterns
    suspicious_patterns = [
        '<script', 'javascript:', 'vbscript:', 'onload=', 'onerror=',
        'eval(', 'alert(', 'document.cookie', 'localStorage', 'sessionStorage'
    ]

    text_lower = text.lower()
    for pattern in suspicious_patterns:
        if pattern in text_lower:
            log_security_event("SUSPICIOUS_INPUT_DETECTED", {
                "input_text": text[:100],  # Log first 100 chars
                "suspicious_pattern": pattern
            })
            return False, "Invalid characters detected"

    return True, None

# Security middleware
@app.before_request
def before_request():
    """Log incoming requests for security monitoring"""
    client_ip = request.remote_addr
    user_agent = request.headers.get('User-Agent', '')

    # Record request metric
    record_metric("incoming_requests", 1, {
        "method": request.method,
        "endpoint": request.endpoint or "unknown"
    })

    # Log suspicious user agents
    if any(pattern in user_agent.lower() for pattern in ['bot', 'crawler', 'scanner']):
        log_security_event("SUSPICIOUS_USER_AGENT", {
            "user_agent": user_agent,
            "client_ip": client_ip
        })

@app.after_request
def add_security_headers(response):
    """Add security headers to all responses"""
    # Basic security headers
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-Frame-Options'] = 'DENY'
    response.headers['X-XSS-Protection'] = '1; mode=block'
    response.headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'

    # CORS headers (same as original)
    allowed_origins = [
        'https://frontend-dot-kbtu-ldoc.uc.r.appspot.com',
        'https://kbtu-ldoc.uc.r.appspot.com'
    ]
    origin = request.headers.get('Origin')

    if origin in allowed_origins:
        response.headers['Access-Control-Allow-Origin'] = origin
        response.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS, PUT, DELETE'
        response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization'
        response.headers['Access-Control-Allow-Credentials'] = 'true'

    return response

@app.route('/')
def home():
    """Homepage with security info"""
    return '''
    <html><body>
        <h1>Hello, GCP - Secure Todo App</h1>
        <p>✅ KMS Encryption: {}</p>
        <p>✅ Security Logging: {}</p>
        <p>✅ Performance Monitoring: {}</p>
        <p><a href="/api/status">Check API Status</a></p>
    </body></html>
    '''.format(
        "Enabled" if KMS_ENABLED else "Disabled",
        "Enabled" if LOGGING_ENABLED else "Disabled",
        "Enabled" if MONITORING_ENABLED else "Disabled"
    )

@app.route('/api/status')
def status():
    """Enhanced status with security info"""
    status_info = {
        'status': 'operational',
        'security_features': {
            'kms_encryption': KMS_ENABLED,
            'security_logging': LOGGING_ENABLED,
            'performance_monitoring': MONITORING_ENABLED
        },
        'features': ['user_separation', 'cors_support', 'encryption', 'security_monitoring'],
        'users_count': len(user_data),
        'global_todos_count': len(todos),
        'version': '3.0-security'
    }

    log_security_event("STATUS_CHECK", status_info)
    return jsonify(status_info)

@app.route('/api/todos', methods=['OPTIONS'])
def handle_options():
    """Handle CORS preflight requests"""
    return '', 200

@app.route('/api/todos', methods=['GET'])
def get_todos():
    """Get todos with automatic decryption"""
    start_time = datetime.utcnow()
    client_id = request.args.get('client_id')

    try:
        if client_id:
            if client_id not in user_data:
                user_data[client_id] = {'todos': [], 'next_id': 1}

            # Decrypt todos before returning
            decrypted_todos = []
            for todo in user_data[client_id]['todos']:
                decrypted_todo = todo.copy()
                decrypted_todo['text'] = decrypt_text(todo.get('text', ''))
                decrypted_todos.append(decrypted_todo)

            response = jsonify(decrypted_todos)
        else:
            # Decrypt global todos
            decrypted_todos = []
            for todo in todos:
                decrypted_todo = todo.copy()
                decrypted_todo['text'] = decrypt_text(todo.get('text', ''))
                decrypted_todos.append(decrypted_todo)

            response = jsonify(decrypted_todos)

        # Record performance metric
        response_time = (datetime.utcnow() - start_time).total_seconds() * 1000
        record_metric("get_todos_response_time", response_time)

        log_security_event("GET_TODOS", {
            "client_id": client_id,
            "response_time_ms": response_time
        })

        return response

    except Exception as e:
        log_security_event("GET_TODOS_ERROR", {
            "error": str(e),
            "client_id": client_id
        })
        return jsonify({'error': 'Failed to retrieve todos'}), 500

@app.route('/api/todos', methods=['POST'])
def create_todo():
    """Create todo with encryption and validation"""
    start_time = datetime.utcnow()
    client_id = request.args.get('client_id')

    try:
        data = request.get_json()
        if not data or 'text' not in data:
            return jsonify({'error': 'text field is required'}), 400

        text = data['text'].strip()
        if not text:
            return jsonify({'error': 'text cannot be empty'}), 400

        if len(text) > 255:
            return jsonify({'error': 'text maximum 255 characters'}), 400

        # Additional security validation
        is_valid, error_message = validate_todo_text(text)
        if not is_valid:
            return jsonify({'error': error_message}), 400

        # Encrypt the todo text
        encrypted_text = encrypt_text(text)

        todo = {
            'id': 0,
            'text': encrypted_text,  # Store encrypted text
            'created_at': datetime.utcnow().isoformat() + 'Z',
            'encrypted': KMS_ENABLED
        }

        if client_id:
            if client_id not in user_data:
                user_data[client_id] = {'todos': [], 'next_id': 1}

            user_todo_data = user_data[client_id]
            todo['id'] = user_todo_data['next_id']
            user_todo_data['todos'].append(todo)
            user_todo_data['next_id'] += 1

            response_data = {
                'count': len(user_todo_data['todos']),
                'user_id': client_id,
                'todos_count': len(user_todo_data['todos']),
                'encrypted': KMS_ENABLED
            }
        else:
            global next_id
            todo['id'] = next_id
            todos.append(todo)
            next_id += 1

            response_data = {
                'count': len(todos),
                'global_todos': len(todos),
                'encrypted': KMS_ENABLED
            }

        # Record metrics
        response_time = (datetime.utcnow() - start_time).total_seconds() * 1000
        record_metric("create_todo_response_time", response_time)
        record_metric("todos_created", 1, {
            "client_specific": str(bool(client_id))
        })

        log_security_event("CREATE_TODO", {
            "client_id": client_id,
            "text_length": len(text),
            "encrypted": KMS_ENABLED,
            "response_time_ms": response_time
        })

        return jsonify(response_data), 201

    except Exception as e:
        log_security_event("CREATE_TODO_ERROR", {
            "error": str(e),
            "client_id": client_id
        })
        return jsonify({'error': 'Failed to create todo'}), 500

if __name__ == '__main__':
    # Only enable debug in development
    debug_mode = os.environ.get('FLASK_DEBUG', 'False').lower() == 'true'
    app.run(host='0.0.0.0', port=8080, debug=debug_mode)