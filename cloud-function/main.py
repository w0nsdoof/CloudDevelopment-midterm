import functions_framework

@functions_framework.http
def notify(request):
    return {"message": "Notification sent from Cloud Function", "timestamp": "2025-10-15"}, 200