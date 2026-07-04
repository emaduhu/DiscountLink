# Production Checklist

## Required provider configuration

Set these values in `backend/.env` before launch:

- `GOOGLE_CLIENT_ID` for Google sign-in token audience validation.
- `BEEM_API_KEY`, `BEEM_SECRET_KEY`, `BEEM_SENDER_ID`, `BEEM_BASE_URL` for OTP SMS.
- `CLICKPESA_API_KEY`, `CLICKPESA_BASE_URL`, `CLICKPESA_WEBHOOK_SECRET` for collections and disbursements.
- `FCM_SERVER_KEY` for delivery notifications.
- `DISCOUNTLINK_ADMIN_TOKEN` for the management dashboard.

## Backend deployment

```bash
composer install --no-dev --optimize-autoloader
php artisan key:generate --force
php artisan migrate --force
php artisan storage:link
php artisan config:cache
php artisan route:cache
php artisan queue:work --tries=3 --timeout=90
```

Use MySQL or PostgreSQL in production. Run Laravel behind HTTPS, configure queue workers with Supervisor/systemd, and point ClickPesa webhooks to `/api/webhooks/clickpesa`.

## Mobile release

Configure Google Sign-In SHA certificates/package IDs in Google Cloud, Firebase Android/iOS apps for FCM, and set the production API URL:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.example.com/api \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=your-oauth-web-client-id.apps.googleusercontent.com
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://api.example.com/api \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=your-oauth-web-client-id.apps.googleusercontent.com
```

`GOOGLE_SERVER_CLIENT_ID` must be the Google OAuth 2.0 Web Client ID from Google Auth Platform/Credentials. It is not the Firebase app ID.

## Payment flow

1. Buyer checks out and receives ClickPesa USSD push.
2. ClickPesa callback updates the collection payment and order status.
3. Deliverer accepts delivery after FCM broadcast.
4. Buyer gives the six-digit delivery code to the deliverer.
5. Deliverer enters the code; backend marks delivery complete and creates ClickPesa disbursement to the verified phone number.
