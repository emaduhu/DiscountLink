<?php

use App\Http\Controllers\DashboardController;
use Illuminate\Support\Facades\Route;

Route::redirect('/', '/dashboard');
Route::get('/admin/login', [DashboardController::class, 'login'])->name('admin.login');
Route::post('/admin/login', [DashboardController::class, 'authenticate'])->name('admin.authenticate');
Route::post('/admin/logout', [DashboardController::class, 'logout'])->name('admin.logout');
Route::post('/dashboard/notifications', [DashboardController::class, 'sendNotification'])->name('dashboard.notifications');
Route::post('/dashboard/users/{user}/toggle', [DashboardController::class, 'toggleUser'])->name('dashboard.users.toggle');
Route::post('/dashboard/products/{product}/toggle', [DashboardController::class, 'toggleProduct'])->name('dashboard.products.toggle');
Route::post('/dashboard/otp-settings', [DashboardController::class, 'updateOtpSettings'])->name('dashboard.otp-settings');
Route::post('/dashboard/categories', [DashboardController::class, 'updateCategories'])->name('dashboard.categories');
Route::post('/dashboard/app-version', [DashboardController::class, 'updateAppVersion'])->name('dashboard.app-version');
Route::get('/dashboard', DashboardController::class)->name('dashboard');
