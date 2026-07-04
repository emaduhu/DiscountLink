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
Route::post('/webhooks/clickpesa', [PaymentWebhookController::class, 'clickpesa'])->name('api.clickpesa.callback');

Route::middleware(AuthenticateApiToken::class)->group(function () {
    Route::get('/me', [AuthController::class, 'me']);
    Route::post('/me/fcm-token', [AuthController::class, 'updateFcm']);
    Route::post('/otp/request', [AuthController::class, 'requestOtp']);
    Route::get('/otp/provider', [AuthController::class, 'otpProvider']);
    Route::post('/otp/verify', [AuthController::class, 'verifyOtp']);

    Route::get('/products', [ProductController::class, 'index']);
    Route::post('/products/image-search', [ProductController::class, 'imageSearch']);

    Route::post('/shops', [ShopController::class, 'store']);
    Route::get('/seller/shops', [ShopController::class, 'mine']);
    Route::post('/shops/{shop}/products', [ShopController::class, 'product']);

    Route::get('/cart', [CartController::class, 'index']);
    Route::post('/cart/{product}', [CartController::class, 'add']);
    Route::post('/checkout', [CartController::class, 'checkout']);
    Route::get('/orders/active', [OrderController::class, 'active']);

    Route::get('/deliveries', [DeliveryController::class, 'available']);
    Route::post('/deliveries/{assignment}/accept', [DeliveryController::class, 'accept']);
    Route::post('/deliveries/{assignment}/location', [DeliveryController::class, 'updateLocation']);
    Route::post('/deliveries/{assignment}/complete', [DeliveryController::class, 'complete']);

    Route::get('/conversations', [ChatController::class, 'conversations']);
    Route::post('/conversations', [ChatController::class, 'start']);
    Route::get('/conversations/{conversation}/messages', [ChatController::class, 'messages']);
    Route::post('/conversations/{conversation}/messages', [ChatController::class, 'send']);
});
