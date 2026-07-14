<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\CartController;
use App\Http\Controllers\Api\ChatController;
use App\Http\Controllers\Api\DeliveryController;
use App\Http\Controllers\Api\OrderController;
use App\Http\Controllers\Api\PaymentWebhookController;
use App\Http\Controllers\Api\ProductController;
use App\Http\Controllers\Api\ShopController;
use App\Http\Middleware\AuthenticateApiToken;
use Illuminate\Support\Facades\Route;

Route::post('/auth/google', [AuthController::class, 'google']);
Route::post('/auth/register', [AuthController::class, 'register']);
Route::post('/auth/login', [AuthController::class, 'login']);
Route::post('/auth/password/forgot', [AuthController::class, 'requestPasswordReset']);
Route::post('/auth/password/reset', [AuthController::class, 'resetPassword']);
Route::post('/webhooks/clickpesa', [PaymentWebhookController::class, 'clickpesa'])->name('api.clickpesa.callback');

Route::middleware(AuthenticateApiToken::class)->group(function () {
    Route::get('/me', [AuthController::class, 'me']);
    Route::put('/me', [AuthController::class, 'updateProfile']);
    Route::post('/me/fcm-token', [AuthController::class, 'updateFcm']);
    Route::post('/email/otp/request', [AuthController::class, 'requestEmailOtp']);
    Route::post('/email/otp/verify', [AuthController::class, 'verifyEmailOtp']);
    Route::post('/otp/request', [AuthController::class, 'requestOtp']);
    Route::get('/otp/provider', [AuthController::class, 'otpProvider']);
    Route::post('/otp/verify', [AuthController::class, 'verifyOtp']);
    Route::get('/discount-links/{token}', [CartController::class, 'showDiscountLink']);
    Route::post('/discount-links/{token}/cart', [CartController::class, 'addDiscountLink']);

    Route::get('/shop-categories', [ShopController::class, 'categories']);

    Route::get('/products', [ProductController::class, 'index']);
    Route::post('/products/image-search', [ProductController::class, 'imageSearch']);
    Route::post('/products/{product}/rating', [ProductController::class, 'rate']);

    Route::post('/shops', [ShopController::class, 'store']);
    Route::get('/seller/shops', [ShopController::class, 'mine']);
    Route::post('/seller/deliverer-invitations', [ShopController::class, 'inviteDeliverer']);
    Route::put('/shops/{shop}', [ShopController::class, 'update']);
    Route::post('/shops/{shop}/products', [ShopController::class, 'product']);
    Route::post('/products/{product}', [ShopController::class, 'updateProduct']);
    Route::put('/products/{product}', [ShopController::class, 'updateProduct']);
    Route::delete('/products/{product}', [ShopController::class, 'destroyProduct']);

    Route::get('/cart', [CartController::class, 'index']);
    Route::post('/cart/{product}', [CartController::class, 'add']);
    Route::delete('/cart/{product}', [CartController::class, 'remove']);
    Route::post('/checkout', [CartController::class, 'checkout']);
    Route::post('/payments/{payment}/ussd-push', [CartController::class, 'resendPaymentPrompt']);
    Route::get('/orders/active', [OrderController::class, 'active']);

    Route::get('/deliveries', [DeliveryController::class, 'available']);
    Route::post('/deliverer/availability', [DeliveryController::class, 'updateAvailability']);
    Route::post('/deliveries/{assignment}/accept', [DeliveryController::class, 'accept']);
    Route::post('/deliveries/{assignment}/location', [DeliveryController::class, 'updateLocation']);
    Route::post('/deliveries/{assignment}/complete', [DeliveryController::class, 'complete']);

    Route::get('/conversations', [ChatController::class, 'conversations']);
    Route::get('/chat/contacts', [ChatController::class, 'contacts']);
    Route::post('/conversations', [ChatController::class, 'start']);
    Route::get('/conversations/{conversation}/messages', [ChatController::class, 'messages']);
    Route::post('/conversations/{conversation}/messages', [ChatController::class, 'send']);
    Route::post('/conversations/{conversation}/discount-links', [ChatController::class, 'createDiscountLink']);
    Route::post('/conversations/{conversation}/report', [ChatController::class, 'report']);
    Route::post('/conversations/{conversation}/block', [ChatController::class, 'block']);
    Route::post('/conversations/{conversation}/unblock', [ChatController::class, 'unblock']);
});
