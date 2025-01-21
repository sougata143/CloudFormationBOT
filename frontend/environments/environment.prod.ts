export const environment = {
  production: true,
  apiUrl: 'https://api.yourdomain.com/api',
  oauth: {
    google: {
      clientId: 'production-google-client-id',
      redirectUri: 'https://yourdomain.com/oauth2/callback'
    }
  },
  security: {
    csrfEnabled: true,
    tokenStorageKey: 'auth_token',
    refreshTokenStorageKey: 'refresh_token'
  }
};