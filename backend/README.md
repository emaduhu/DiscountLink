# DiscountLink

DiscountLink is a Laravel API/admin backend plus Flutter mobile app for discounted product selling, buying, delivery dispatch, phone verification, USSD push collections, disbursements, FCM notifications, and user chat.

## Structure

- `backend/` Laravel API and admin/reporting dashboard.
- `mobile/` Flutter Android/iOS app.
- `docs/production.md` deployment and provider checklist.

## Backend quick start

```bash
cd backend
cp .env.example .env
php artisan key:generate
php artisan migrate --seed
php artisan serve
```

Admin dashboard: `http://127.0.0.1:8000/dashboard?token=change-me`

Sample app users:

- Buyer: `buyer@discountlink.local` or `255700000001`
- Seller: `seller@discountlink.local` or `255700000002`
- Deliverer: `deliverer@discountlink.local` or `255700000003`

Password for all sample users: `password`.

## Mobile quick start

```bash
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

For local Google auth testing, the backend accepts `dev-google-token:user@example.com` only when `APP_ENV=local`.
