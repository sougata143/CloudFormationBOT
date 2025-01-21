import { Injectable } from '@angular/core';
import {
  HttpRequest,
  HttpHandler,
  HttpEvent,
  HttpInterceptor,
  HttpErrorResponse
} from '@angular/common/http';
import { Observable, throwError } from 'rxjs';
import { catchError, switchMap } from 'rxjs/operators';
import { AuthService } from './auth.service';
import { Router } from '@angular/router';

@Injectable()
export class AuthInterceptor implements HttpInterceptor {
  constructor(
    private authService: AuthService,
    private router: Router
  ) {}

  intercept(request: HttpRequest<unknown>, next: HttpHandler): Observable<HttpEvent<unknown>> {
    // Add JWT token to request headers
    const token = this.authService.getToken();
    
    if (token) {
      request = this.addTokenHeader(request, token);
    }

    return next.handle(request).pipe(
      catchError((error: HttpErrorResponse) => {
        // Handle unauthorized access
        if (error.status === 401) {
          return this.handleUnauthorizedError(request, next);
        }
        return throwError(() => error);
      })
    );
  }

  private addTokenHeader(request: HttpRequest<any>, token: string) {
    return request.clone({
      setHeaders: {
        Authorization: `Bearer ${token}`,
        'X-CSRF-Token': this.authService.getCsrfToken()
      }
    });
  }

  private handleUnauthorizedError(request: HttpRequest<any>, next: HttpHandler) {
    // Attempt token refresh
    return this.authService.refreshToken().pipe(
      switchMap((newToken) => {
        const updatedRequest = this.addTokenHeader(request, newToken);
        return next.handle(updatedRequest);
      }),
      catchError((refreshError) => {
        // Logout user if refresh fails
        this.authService.logout();
        this.router.navigate(['/login']);
        return throwError(() => refreshError);
      })
    );
  }
}