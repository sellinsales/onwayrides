<?php

use App\Http\Controllers\Api\BootstrapController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\HealthController;
use Illuminate\Support\Facades\Route;

Route::get('/health', HealthController::class)->name('api.health');
Route::get('/bootstrap', BootstrapController::class)->name('api.bootstrap');
Route::post('/auth/login', [AuthController::class, 'login'])->name('api.auth.login');
Route::get('/auth/me', [AuthController::class, 'me'])->name('api.auth.me');
