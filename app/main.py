from flask import Flask, jsonify, request
from datetime import datetime

app = Flask(__name__)

# User-specific storage: {client_id: {todos: [], next_id: 1}}
user_data = {}
# Global storage for backward compatibility
todos = []
next_id = 1

# Add CORS headers to allow frontend access
@app.after_request
def add_cors_headers(response):
    # Allow requests from the frontend subdomain
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

# Handle preflight requests
@app.route('/api/todos', methods=['OPTIONS'])
def handle_options():
    return '', 200

@app.route('/')
def home():
    return '<html><body><h1>Hello, GCP</h1></body></html>'

@app.route('/api/status')
def status():
    return jsonify({
        'status': 'operational',
        'features': ['user_separation', 'cors_support', 'client_id'],
        'users_count': len(user_data),
        'global_todos_count': len(todos),
        'version': '2.0'
    })

@app.route('/api/todos', methods=['GET'])
def get_todos():
    client_id = request.args.get('client_id')

    if client_id:
        # User-specific todos
        if client_id not in user_data:
            user_data[client_id] = {'todos': [], 'next_id': 1}
        return jsonify(user_data[client_id]['todos'])
    else:
        # Global todos for backward compatibility
        return jsonify(todos)

@app.route('/api/todos', methods=['POST'])
def create_todo():
    client_id = request.args.get('client_id')
    data = request.get_json()

    if not data or 'text' not in data:
        return jsonify({'error': 'text field is required'}), 400

    text = data['text'].strip()
    if not text:
        return jsonify({'error': 'text cannot be empty'}), 400

    if len(text) > 255:
        return jsonify({'error': 'text maximum 255 characters'}), 400

    todo = {
        'id': 0,  # Will be set based on user context
        'text': text,
        'created_at': datetime.utcnow().isoformat() + 'Z'
    }

    if client_id:
        # User-specific todo
        if client_id not in user_data:
            user_data[client_id] = {'todos': [], 'next_id': 1}

        user_todo_data = user_data[client_id]
        todo['id'] = user_todo_data['next_id']
        user_todo_data['todos'].append(todo)
        user_todo_data['next_id'] += 1

        return jsonify({
            'count': len(user_todo_data['todos']),
            'user_id': client_id,
            'todos_count': len(user_todo_data['todos'])
        }), 201
    else:
        # Global todo for backward compatibility
        global next_id
        todo['id'] = next_id
        todos.append(todo)
        next_id += 1

        return jsonify({
            'count': len(todos),
            'global_todos': len(todos)
        }), 201

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=True)