<?php

namespace App\Providers;

use App\Contracts\Auth\FirebaseTokenVerifier;
use App\Services\Auth\KreaitFirebaseTokenVerifier;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        $this->app->singleton(FirebaseTokenVerifier::class, KreaitFirebaseTokenVerifier::class);
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        //
    }
}
