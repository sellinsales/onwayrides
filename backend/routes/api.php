<?php

use App\Http\Controllers\Api\BootstrapController;
use App\Http\Controllers\Api\AdminMarketingController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\HealthController;
use Illuminate\Support\Facades\Route;

Route::get('/health', HealthController::class)->name('api.health');
Route::get('/bootstrap', BootstrapController::class)->name('api.bootstrap');
Route::post('/auth/login', [AuthController::class, 'login'])->name('api.auth.login');
Route::get('/auth/me', [AuthController::class, 'me'])->name('api.auth.me');
Route::patch('/auth/onboarding', [AuthController::class, 'completeOnboarding'])->name('api.auth.onboarding');
Route::get('/admin/marketing/contacts', [AdminMarketingController::class, 'index'])->name('api.admin.marketing.contacts');
Route::get('/admin/marketing/contacts/export', [AdminMarketingController::class, 'export'])->name('api.admin.marketing.contacts.export');
