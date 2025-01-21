# Example integration test for microservice communication
import requests
from config import SERVICE_ENDPOINTS

def test_user_service_integration():
    # Test user creation flow across services
    user_data = {
        "username": "integration_test_user",
        "email": "test@example.com"
    }
    
    # Create user
    create_response = requests.post(
        f"{SERVICE_ENDPOINTS['user_service']}/users", 
        json=user_data
    )
    assert create_response.status_code == 201
    
    # Authenticate user
    auth_response = requests.post(
        f"{SERVICE_ENDPOINTS['auth_service']}/login", 
        json={
            "username": user_data['username'],
            "password": "test_password"
        }
    )
    assert auth_response.status_code == 200
    assert 'access_token' in auth_response.json()