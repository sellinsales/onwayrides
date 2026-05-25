<?php

namespace App\Providers;

use App\Contracts\Auth\FirebaseTokenVerifier;
use App\Services\Auth\KreaitFirebaseTokenVerifier;
use App\Services\Firebase\FirebaseAdminProject;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        $this->app->singleton(FirebaseAdminProject::class);
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
