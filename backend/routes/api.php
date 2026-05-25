<?php

use App\Http\Controllers\Api\BootstrapController;
use App\Http\Controllers\Api\BookingController;
use App\Http\Controllers\Api\DeviceTokenController;
use App\Http\Controllers\Api\DriverRequestController;
use App\Http\Controllers\Api\DriverModeController;
use App\Http\Controllers\Api\DriverDocumentController;
use App\Http\Controllers\Api\AdminMarketingController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\HealthController;
use App\Http\Controllers\Api\OnboardingController;
use Illuminate\Support\Facades\Route;

Route::get('/health', HealthController::class)->name('api.health');
Route::get('/bootstrap', BootstrapController::class)->name('api.bootstrap');
Route::get('/bookings', [BookingController::class, 'index'])->name('api.bookings.index');
Route::post('/bookings', [BookingController::class, 'store'])->name('api.bookings.store');
Route::patch('/bookings/{booking}/status', [BookingController::class, 'updateStatus'])->name('api.bookings.status.update');
Route::post('/bookings/{booking}/tracking-points', [BookingController::class, 'storeTrackingPoint'])->name('api.bookings.tracking.store');
Route::post('/devices/token', [DeviceTokenController::class, 'store'])->name('api.devices.token.store');
Route::delete('/devices/token', [DeviceTokenController::class, 'destroy'])->name('api.devices.token.destroy');
Route::patch('/driver/mode', [DriverModeController::class, 'update'])->name('api.driver.mode.update');
Route::get('/driver/requests', [DriverRequestController::class, 'index'])->name('api.driver.requests.index');
Route::post('/driver/requests/{booking}/accept', [DriverRequestController::class, 'accept'])->name('api.driver.requests.accept');
Route::post('/driver/requests/{booking}/reject', [DriverRequestController::class, 'reject'])->name('api.driver.requests.reject');
Route::post('/driver/requests/{booking}/counter-offer', [DriverRequestController::class, 'counterOffer'])->name('api.driver.requests.counter-offer');
Route::get('/onboarding/reference-data', [OnboardingController::class, 'referenceData'])->name('api.onboarding.reference-data');
Route::get('/onboarding/workspace', [OnboardingController::class, 'workspace'])->name('api.onboarding.workspace');
Route::patch('/onboarding/driver', [OnboardingController::class, 'saveDriverDraft'])->name('api.onboarding.driver');
Route::patch('/onboarding/fleet', [OnboardingController::class, 'saveFleetDraft'])->name('api.onboarding.fleet');
Route::post('/onboarding/driver-documents', [DriverDocumentController::class, 'store'])->name('api.onboarding.driver-documents.store');
Route::get('/onboarding/driver-documents/{documentId}', [DriverDocumentController::class, 'show'])->name('api.onboarding.driver-documents.show');
Route::post('/auth/login', [AuthController::class, 'login'])->name('api.auth.login');
Route::get('/auth/me', [AuthController::class, 'me'])->name('api.auth.me');
Route::patch('/auth/onboarding', [AuthController::class, 'completeOnboarding'])->name('api.auth.onboarding');
Route::get('/admin/marketing/contacts', [AdminMarketingController::class, 'index'])->name('api.admin.marketing.contacts');
Route::get('/admin/marketing/contacts/export', [AdminMarketingController::class, 'export'])->name('api.admin.marketing.contacts.export');
