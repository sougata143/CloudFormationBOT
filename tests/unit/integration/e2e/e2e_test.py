# Selenium-based E2E testing
from selenium import webdriver
from selenium.webdriver.common.by import By

class TestUserJourney:
    def setup_method(self):
        self.driver = webdriver.Chrome()
        self.driver.get("http://localhost:4200")  # Angular app URL

    def test_user_registration_flow(self):
        # Navigate to registration
        registration_link = self.driver.find_element(By.ID, "register-link")
        registration_link.click()

        # Fill registration form
        username_input = self.driver.find_element(By.ID, "username")
        email_input = self.driver.find_element(By.ID, "email")
        password_input = self.driver.find_element(By.ID, "password")
        submit_button = self.driver.find_element(By.ID, "submit-registration")

        username_input.send_keys("e2e_test_user")
        email_input.send_keys("e2e@example.com")
        password_input.send_keys("secure_password_123")
        submit_button.click()

        # Verify registration success
        success_message = self.driver.find_element(By.ID, "registration-success")
        assert success_message.is_displayed()

    def teardown_method(self):
        self.driver.quit()