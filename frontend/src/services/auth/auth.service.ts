import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { BehaviorSubject, Observable } from 'rxjs';
import { tap } from 'rxjs/operators';
import { environment } from '../environments/environment';
import jwtDecode from 'jwt-decode';

interface AuthResponse {
  token: string;
  refreshToken: string;
}

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  private tokenSubject = new BehaviorSubject<string | null>(null);
  private csrfToken: string | null = null;

  constructor(private http: HttpClient) {
    // Initialize token from local storage
    const storedToken = localStorage.getItem('auth_token');
    if (storedToken) {
      this.tokenSubject.next(storedToken);
    }
  }

  login(credentials: { username: string, password: string }): Observable<AuthResponse> {
    return this.http.post<AuthResponse>(`${environment.apiUrl}/auth/login`, credentials).pipe(
      tap(response => this.setSession(response))
    );
  }

  refreshToken(): Observable<string> {
    return this.http.post<AuthResponse>(`${environment.apiUrl}/auth/refresh`, {}).pipe(
      tap(response => this.setSession(response))
    );
  }

  logout() {
    localStorage.removeItem('auth_token');
    localStorage.removeItem('refresh_token');
    this.tokenSubject.next(null);
  }

  getToken(): string | null {
    return this.tokenSubject.value;
  }

  getCsrfToken(): string | null {
    return this.csrfToken;
  }

  private setSession(authResult: AuthResponse) {
    localStorage.setItem('auth_token', authResult.token);
    localStorage.setItem('refresh_token', authResult.refreshToken);
    this.tokenSubject.next(authResult.token);
    
    // Extract and store CSRF token from JWT
    const decodedToken: any = jwtDecode(authResult.token);
    this.csrfToken = decodedToken.csrfToken;
  }

  isTokenExpired(): boolean {
    const token = this.getToken();
    if (!token) return true;

    const decoded: any = jwtDecode(token);
    return decoded.exp < Date.now() / 1000;
  }
}