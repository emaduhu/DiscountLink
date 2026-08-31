# Production Checklist

## Required provider configuration

Set these values in `backend/.env` before launch:

- `DB_CONNECTION=mysql`, plus the production `DB_HOST`, `DB_PORT`, `DB_DATABASE`, `DB_USERNAME`, and `DB_PASSWORD` values.
- `GOOGLE_CLIENT_ID` for Google sign-in token audience validation.
- `SMS_PROVIDER=beem_africa`, `BEEM_ACCESS_KEY`, `BEEM_SECRET_KEY`, `BEEM_SENDER=VIGOURTECH`, `BEEM_SMS_URL=https://apisms.beem.africa/v1/send` for OTP SMS. The older `BEEM_API_KEY`, `BEEM_SENDER_ID`, and `BEEM_BASE_URL` names remain supported as fallbacks.
- `CLICKPESA_API_KEY`, `CLICKPESA_BASE_URL`, `CLICKPESA_WEBHOOK_SECRET`, `CLICKPESA_QUEUE`, and `CLICKPESA_QUEUE_TRIES` for queued collections and disbursements. Configure ClickPesa to sign callbacks and set the matching checksum secret; paid product-campaign callbacks are deliberately ignored when this secret is blank or the checksum is invalid.
- `FCM_SERVER_KEY` for delivery notifications.
- `DISCOUNTLINK_ADMIN_EMAIL` and `DISCOUNTLINK_ADMIN_PASSWORD` for the initial management dashboard admin account.

## Backend deployment

For cPanel deployment on `dl.vigourtech.net`, place the Laravel application in:

```text
dl.vigourtech.net/laravel
```

The domain document root should route requests to `laravel/public/index.php`.

```bash
composer install --no-dev --optimize-autoloader
php artisan key:generate --force
php artisan migrate --force
php artisan storage:link
php artisan config:cache
php artisan route:cache
php artisan queue:work --queue=payments,default --tries=5 --timeout=90
```

Use MySQL in production. The default `database` queue persists ClickPesa payment, disbursement, and product-campaign jobs before provider calls, so failed requests can retry and later land in `failed_jobs` instead of being lost. Run Laravel behind HTTPS, keep a queue worker processing both `payments` and `default`, and point signed ClickPesa webhooks to `/api/webhooks/clickpesa`. Configure the SMS and FCM campaign unit prices from the admin Settings page only after callback checksum validation has been verified.

Product media requests can contain two 50 MB videos plus three 5 MB images. Configure the cPanel PHP runtime with `upload_max_filesize=50M`, `post_max_size=128M`, and `max_file_uploads` of at least `5`; otherwise PHP will discard an otherwise valid multipart request before Laravel can validate it. Keep the public storage link in place so the web server can serve media URLs and video byte-range requests directly.

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

1. Buyer checks out and the ClickPesa USSD push is queued for retryable processing.
2. ClickPesa callback updates the collection payment and order status.
3. Deliverer accepts delivery after FCM broadcast.
4. Buyer gives the four-digit delivery code received in-app, by SMS, and by push notification to the deliverer.
5. Deliverer enters the code; backend marks delivery complete and queues ClickPesa disbursements to the verified phone numbers.
