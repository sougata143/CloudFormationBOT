# Example unit test for authentication service
import pytest
from services.auth import AuthService

class TestAuthService:
    def test_password_hashing(self):
        auth_service = AuthService()
        password = "test_password"
        hashed_password = auth_service.hash_password(password)
        
        assert hashed_password != password
        assert auth_service.verify_password(password, hashed_password)

    def test_jwt_token_generation(self):
        auth_service = AuthService()
        user_id = "user123"
        token = auth_service.generate_jwt_token(user_id)
        
        assert token is not None
        assert len(token) > 0