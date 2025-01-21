// Example Angular component test
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { LoginComponent } from './login.component';
import { AuthService } from '../services/auth.service';

describe('LoginComponent', () => {
  let component: LoginComponent;
  let authService: AuthService;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      declarations: [ LoginComponent ],
      providers: [ AuthService ]
    }).compileComponents();
  });

  it('should create login form', () => {
    const fixture = TestBed.createComponent(LoginComponent);
    component = fixture.componentInstance;
    expect(component.loginForm).toBeTruthy();
  });

  it('should validate login credentials', () => {
    component.loginForm.setValue({
      username: 'testuser',
      password: 'password123'
    });
    expect(component.loginForm.valid).toBeTruthy();
  });
});