<?php

use App\Http\Controllers\DashboardController;
use Illuminate\Support\Facades\Route;

Route::redirect('/', '/dashboard');
Route::get('/admin/login', [DashboardController::class, 'login'])->name('admin.login');
Route::post('/admin/login', [DashboardController::class, 'authenticate'])->name('admin.authenticate');
Route::post('/admin/logout', [DashboardController::class, 'logout'])->name('admin.logout');
Route::post('/dashboard/notifications', [DashboardController::class, 'sendNotification'])->name('dashboard.notifications');
Route::post('/dashboard/users/{user}/toggle', [DashboardController::class, 'toggleUser'])->name('dashboard.users.toggle');
Route::post('/dashboard/users/{user}/restore', [DashboardController::class, 'restoreUser'])->name('dashboard.users.restore');
Route::post('/dashboard/shops/{shop}/restore', [DashboardController::class, 'restoreShop'])->name('dashboard.shops.restore');
Route::post('/dashboard/products/{product}/toggle', [DashboardController::class, 'toggleProduct'])->name('dashboard.products.toggle');
Route::post('/dashboard/conversations/{conversation}/toggle', [DashboardController::class, 'toggleConversation'])->name('dashboard.conversations.toggle');
Route::post('/dashboard/conversation-reports/{report}/close', [DashboardController::class, 'closeConversationReport'])->name('dashboard.conversation-reports.close');
Route::post('/dashboard/otp-settings', [DashboardController::class, 'updateOtpSettings'])->name('dashboard.otp-settings');
Route::post('/dashboard/categories', [DashboardController::class, 'updateCategories'])->name('dashboard.categories');
Route::post('/dashboard/shop-registration-fee', [DashboardController::class, 'updateShopRegistrationFee'])->name('dashboard.shop-registration-fee');
Route::post('/dashboard/service-fee', [DashboardController::class, 'updateServiceFee'])->name('dashboard.service-fee');
Route::post('/dashboard/campaign-pricing', [DashboardController::class, 'updateCampaignPricing'])->name('dashboard.campaign-pricing');
Route::post('/dashboard/payments/{payment}/ussd-push', [DashboardController::class, 'resendPaymentPrompt'])->name('dashboard.payments.ussd-push');
Route::get('/dashboard', DashboardController::class)->name('dashboard');
