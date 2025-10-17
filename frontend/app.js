// Configuration and state
class TodoApp {
    constructor() {
        this.API_BASE_URLS = [
            'https://kbtu-ldoc.uc.r.appspot.com',
            'http://136.113.60.130',
            'http://localhost:8080'
        ];
        this.apiBaseUrl = this.API_BASE_URLS[0]; // Start with App Engine
        this.clientId = this.getOrCreateClientId();
        this.todos = [];
        this.isLoading = false;

        this.init();
    }

    // Client ID management for user separation
    getOrCreateClientId() {
        let clientId = localStorage.getItem('todo_client_id');
        if (!clientId) {
            clientId = this.generateClientId();
            localStorage.setItem('todo_client_id', clientId);
        }
        return clientId;
    }

    generateClientId() {
        return 'user_' + Math.random().toString(36).substr(2, 9) + '_' + Date.now().toString(36);
    }

    // Initialize the app
    init() {
        this.bindEvents();
        this.updateUI();
        this.checkBackendHealth();
        this.loadTodos();
    }

    // Event binding
    bindEvents() {
        const todoForm = document.getElementById('todoForm');
        const todoInput = document.getElementById('todoInput');
        const refreshBtn = document.getElementById('refreshBtn');
        const retryBtn = document.getElementById('retryBtn');

        todoForm.addEventListener('submit', (e) => {
            e.preventDefault();
            this.addTodo();
        });

        todoInput.addEventListener('input', () => {
            this.updateCharCount();
        });

        refreshBtn.addEventListener('click', () => {
            this.loadTodos();
        });

        retryBtn.addEventListener('click', () => {
            this.loadTodos();
        });
    }

    // UI Updates
    updateUI() {
        this.updateBackendStatus();
        this.updateUserInfo();
        this.updateCharCount();
        this.renderTodos();
    }

    updateBackendStatus() {
        const statusEl = document.getElementById('backendStatus');
        const apiUrlEl = document.getElementById('apiUrl');

        statusEl.textContent = '🔌 Connected';
        statusEl.className = 'backend-status';
        apiUrlEl.textContent = this.apiBaseUrl;
    }

    updateUserInfo() {
        const userInfoEl = document.getElementById('userInfo');
        const shortId = this.clientId.substring(0, 12) + '...';
        userInfoEl.textContent = `👤 User: ${shortId}`;
    }

    updateCharCount() {
        const input = document.getElementById('todoInput');
        const charCountEl = document.getElementById('charCount');
        charCountEl.textContent = input.value.length;
    }

    // Backend health check
    async checkBackendHealth() {
        const statusEl = document.getElementById('backendStatus');

        for (const baseUrl of this.API_BASE_URLS) {
            try {
                const response = await fetch(`${baseUrl}/api/todos`, {
                    method: 'GET',
                    headers: {
                        'Accept': 'application/json'
                    }
                });

                if (response.ok) {
                    this.apiBaseUrl = baseUrl;
                    this.updateBackendStatus();
                    return;
                }
            } catch (error) {
                console.log(`Failed to connect to ${baseUrl}:`, error.message);
            }
        }

        // All backends failed
        statusEl.textContent = '❌ Backend offline';
        statusEl.className = 'backend-status error';
        this.showError('Unable to connect to any backend server');
    }

    // API methods
    async loadTodos() {
        if (this.isLoading) return;

        this.setLoading(true);

        try {
            const url = `${this.apiBaseUrl}/api/todos?client_id=${this.clientId}`;
            const response = await fetch(url, {
                method: 'GET',
                headers: {
                    'Accept': 'application/json',
                    'Content-Type': 'application/json'
                }
            });

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }

            const data = await response.json();
            this.todos = Array.isArray(data) ? data : [];
            this.renderTodos();
            this.hideError();

        } catch (error) {
            console.error('Failed to load todos:', error);

            // Fallback to global todos if client-specific fails
            if (this.apiBaseUrl.includes('client_id')) {
                try {
                    const fallbackUrl = `${this.apiBaseUrl}/api/todos`;
                    const response = await fetch(fallbackUrl);
                    if (response.ok) {
                        const data = await response.json();
                        this.todos = Array.isArray(data) ? data : [];
                        this.renderTodos();
                        this.hideError();
                        return;
                    }
                } catch (fallbackError) {
                    console.error('Fallback also failed:', fallbackError);
                }
            }

            this.showError('Failed to load todos. Please try again.');
        } finally {
            this.setLoading(false);
        }
    }

    async addTodo() {
        const input = document.getElementById('todoInput');
        const addBtn = document.getElementById('addBtn');
        const text = input.value.trim();

        if (!text) {
            this.showError('Please enter a todo item');
            return;
        }

        if (text.length > 255) {
            this.showError('Todo must be 255 characters or less');
            return;
        }

        this.setButtonLoading(addBtn, true);

        try {
            const url = `${this.apiBaseUrl}/api/todos?client_id=${this.clientId}`;
            const response = await fetch(url, {
                method: 'POST',
                headers: {
                    'Accept': 'application/json',
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ text })
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(errorData.error || `HTTP ${response.status}`);
            }

            const result = await response.json();

            // Clear input and reload todos
            input.value = '';
            this.updateCharCount();
            this.loadTodos();

            // Show success feedback
            this.showSuccess('Todo added successfully!');

        } catch (error) {
            console.error('Failed to add todo:', error);
            this.showError(error.message || 'Failed to add todo');
        } finally {
            this.setButtonLoading(addBtn, false);
        }
    }

    // UI state management
    setLoading(isLoading) {
        this.isLoading = isLoading;
        const loadingState = document.getElementById('loadingState');
        const emptyState = document.getElementById('emptyState');
        const errorState = document.getElementById('errorState');
        const todoList = document.getElementById('todoList');

        if (isLoading) {
            loadingState.style.display = 'block';
            emptyState.style.display = 'none';
            errorState.style.display = 'none';
            todoList.style.display = 'none';
        }
    }

    setButtonLoading(button, isLoading) {
        const btnText = button.querySelector('.btn-text');
        const btnSpinner = button.querySelector('.btn-spinner');

        if (isLoading) {
            btnText.style.display = 'none';
            btnSpinner.style.display = 'inline-block';
            button.disabled = true;
        } else {
            btnText.style.display = 'inline-block';
            btnSpinner.style.display = 'none';
            button.disabled = false;
        }
    }

    renderTodos() {
        const emptyState = document.getElementById('emptyState');
        const errorState = document.getElementById('errorState');
        const todoList = document.getElementById('todoList');
        const todoCount = document.getElementById('todoCount');
        const loadingState = document.getElementById('loadingState');

        // Hide loading state
        loadingState.style.display = 'none';

        // Update count
        todoCount.textContent = `${this.todos.length} todo${this.todos.length !== 1 ? 's' : ''}`;

        if (this.todos.length === 0) {
            emptyState.style.display = 'block';
            errorState.style.display = 'none';
            todoList.style.display = 'none';
        } else {
            emptyState.style.display = 'none';
            errorState.style.display = 'none';
            todoList.style.display = 'flex';

            // Sort todos by ID (most recent first)
            const sortedTodos = [...this.todos].sort((a, b) => b.id - a.id);

            todoList.innerHTML = sortedTodos.map(todo => `
                <li class="todo-item">
                    <div class="todo-content">
                        <div class="todo-text">${this.escapeHtml(todo.text)}</div>
                        <div class="todo-meta">
                            <span class="todo-id">#${todo.id}</span>
                            <span>•</span>
                            <span>${this.formatDate(todo.created_at)}</span>
                        </div>
                    </div>
                </li>
            `).join('');
        }
    }

    showError(message) {
        const errorState = document.getElementById('errorState');
        const errorText = errorState.querySelector('p');
        errorText.innerHTML = `${message}. <button id="retryBtn" class="retry-link">Try again</button>`;

        // Re-bind retry button
        document.getElementById('retryBtn').addEventListener('click', () => {
            this.loadTodos();
        });

        errorState.style.display = 'block';
        document.getElementById('emptyState').style.display = 'none';
        document.getElementById('todoList').style.display = 'none';
    }

    showSuccess(message) {
        // Create temporary success message
        const successEl = document.createElement('div');
        successEl.className = 'message success';
        successEl.innerHTML = `✅ ${message}`;

        const form = document.getElementById('todoForm');
        form.insertBefore(successEl, form.firstChild);

        // Remove after 3 seconds
        setTimeout(() => {
            if (successEl.parentNode) {
                successEl.parentNode.removeChild(successEl);
            }
        }, 3000);
    }

    hideError() {
        document.getElementById('errorState').style.display = 'none';
    }

    // Utility methods
    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    formatDate(dateString) {
        try {
            const date = new Date(dateString);
            const now = new Date();
            const diffMs = now - date;
            const diffMins = Math.floor(diffMs / 60000);
            const diffHours = Math.floor(diffMins / 60);
            const diffDays = Math.floor(diffHours / 24);

            if (diffMins < 1) {
                return 'just now';
            } else if (diffMins < 60) {
                return `${diffMins} minute${diffMins !== 1 ? 's' : ''} ago`;
            } else if (diffHours < 24) {
                return `${diffHours} hour${diffHours !== 1 ? 's' : ''} ago`;
            } else if (diffDays < 7) {
                return `${diffDays} day${diffDays !== 1 ? 's' : ''} ago`;
            } else {
                return date.toLocaleDateString();
            }
        } catch (error) {
            return dateString;
        }
    }
}

// Initialize app when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    new TodoApp();
});

// Handle page visibility changes to refresh when user returns
document.addEventListener('visibilitychange', () => {
    if (!document.hidden) {
        // Optionally refresh when user returns to the tab
        // location.reload();
    }
});