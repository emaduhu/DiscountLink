# DiscountLink

DiscountLink is a Laravel API/admin backend plus Flutter mobile app for discounted product selling, buying, delivery dispatch, phone verification, USSD push collections, disbursements, FCM notifications, and user chat.

## Structure

- `backend/` Laravel API and admin/reporting dashboard.
- `mobile/` Flutter Android/iOS app.
- `docs/production.md` deployment and provider checklist.

## Backend quick start

Create a MySQL database named `discountlink`, copy `.env.example`, and set the
`DB_HOST`, `DB_PORT`, `DB_DATABASE`, `DB_USERNAME`, and `DB_PASSWORD` values for
that database. The application and its test suite are MySQL-only.

```bash
cd backend
cp .env.example .env
php artisan key:generate
php artisan migrate --seed
php artisan serve
```

For tests, create a separate MySQL database named `discountlink_test` (or
override the `DB_*` variables when running the suite), then run `composer test`.

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

## Product media API

Create a product with `POST /api/shops/{shop}/products` using multipart form data. Send exactly three files as `product_images[]` and optionally up to two files as `product_videos[]`. JPG, PNG, and WebP images are accepted up to 5 MB each; MP4, MOV, and WebM videos are accepted up to 50 MB each. The legacy `images[]` URL input remains supported instead of `product_images[]`, but the two image inputs cannot be combined.

`POST` or `PUT /api/products/{product}` keeps an omitted media group unchanged. Supplying `product_images[]` replaces all three images, supplying `product_videos[]` replaces all videos, and `clear_videos=true` removes every video.

Every serialized product retains the legacy `images` URL array and includes a carousel-ready `media` array ordered by its zero-based `position`:

```json
{
  "images": [
    "https://example.test/storage/products/1/images/00-first.webp",
    "https://example.test/storage/products/1/images/01-second.webp",
    "https://example.test/storage/products/1/images/02-third.webp"
  ],
  "media": [
    {
      "id": 1,
      "type": "image",
      "url": "https://example.test/storage/products/1/images/00-hash.webp",
      "position": 0,
      "mime_type": "image/webp",
      "size_bytes": 48231
    }
  ]
}
```

Images occupy positions 0–2 and videos positions 3–4. Uploaded images are resized to at most 1920 pixels on the longest edge and encoded as WebP when that reduces storage. Media uses content-hashed, product-scoped paths; replacements and product removal clean up unreferenced local files. Videos remain directly addressable on the public disk so the web server can serve byte-range requests. If `ffprobe` is installed, video dimensions and duration are also recorded internally.
