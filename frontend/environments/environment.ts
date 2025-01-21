export const environment = {
  production: false,
  apiUrl: 'http://localhost:8080/api',
  oauth: {
    google: {
      clientId: 'your-google-client-id',
      redirectUri: 'http://localhost:4200/oauth2/callback'
    }
  },
  security: {
    csrfEnabled: true,
    tokenStorageKey: 'auth_token',
    refreshTokenStorageKey: 'refresh_token'
  }
};