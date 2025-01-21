# Locust-based performance testing
from locust import HttpUser, task, between

class UserBehavior(HttpUser):
    wait_time = between(1, 5)

    @task(1)
    def login(self):
        self.client.post("/auth/login", json={
            "username": "performance_test_user",
            "password": "test_password"
        })

    @task(2)
    def get_user_profile(self):
        self.client.get("/users/profile", headers={
            "Authorization": "Bearer test_token"
        })