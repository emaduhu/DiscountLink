# DiscountLink v1.0.36 Store Assets

These assets were generated from actual app screens using the v1.0.36 screenshot harness. Screenshots are placed inside branded store-promo frames so the upload assets stay visually useful even when the underlying app screen has a light background. PNG deliverables were flattened to remove alpha channels while preserving dimensions.

## Google Play

- App icon: `play_store/icon/play_store_icon_512x512.png` — 512x512
- Feature graphic: `play_store/feature_graphic/feature_graphic_1024x500.jpg` — 1024x500
- Phone screenshots: `play_store/phone/screenshots/` — 1080x1920
- Phone splash/login/registration images: `play_store/phone/splash_login/` — 1080x1920
- 7-inch tablet screenshots: `play_store/7_inch_tablet/screenshots/` — 1200x1920
- 7-inch tablet splash/login/registration images: `play_store/7_inch_tablet/splash_login/` — 1200x1920
- 10-inch tablet screenshots: `play_store/10_inch_tablet/screenshots/` — 1600x2560
- 10-inch tablet splash/login/registration images: `play_store/10_inch_tablet/splash_login/` — 1600x2560

## App Store

- App icon: `app_store/app_icon/app_icon_1024x1024.png` — 1024x1024
- iPhone 6.9-inch screenshots: `app_store/iphone_6_9/screenshots/` — 1320x2868
- iPhone 6.9-inch splash/login/registration images: `app_store/iphone_6_9/splash_login/` — 1320x2868
- iPad 13-inch screenshots: `app_store/ipad_13/screenshots/` — 2048x2732
- iPad 13-inch splash/login/registration images: `app_store/ipad_13/splash_login/` — 2048x2732

## Screenshot order

1. Seller marketplace access
2. Seller fixed-amount discount
3. Seller buyer active orders
4. Delivery tracking
5. Secure chat

## Generation helpers

- `tool/store_screenshot_app.dart` renders deterministic app states with mocked API data inside branded store-promo frames.
- `tool/store_asset_generation_test.dart` regenerates every Play Store and App Store phone/tablet image with `flutter test --update-goldens`.
- `tool/generate_play_feature_graphic.swift` composes the Play feature graphic from real phone screenshots and the app icon.
- `tool/flatten_store_png_alpha.swift` removes PNG alpha channels for upload-ready assets.
