<?php

use App\Http\Controllers\Api\BootstrapController;
use App\Http\Controllers\Api\DriverDocumentController;
use App\Http\Controllers\Api\AdminMarketingController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\HealthController;
use App\Http\Controllers\Api\OnboardingController;
use Illuminate\Support\Facades\Route;

Route::get('/health', HealthController::class)->name('api.health');
Route::get('/bootstrap', BootstrapController::class)->name('api.bootstrap');
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
