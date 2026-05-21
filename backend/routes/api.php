<?php

use App\Http\Controllers\Api\BootstrapController;
use App\Http\Controllers\Api\HealthController;
use Illuminate\Support\Facades\Route;

Route::get('/health', HealthController::class)->name('api.health');
Route::get('/bootstrap', BootstrapController::class)->name('api.bootstrap');
