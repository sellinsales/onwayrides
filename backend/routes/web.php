<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return response()->json([
        'app' => 'OnWay Rides Backend',
        'framework' => 'Laravel',
        'status' => 'ok',
        'endpoints' => [
            'health' => url('/api/health'),
            'bootstrap' => url('/api/bootstrap'),
            'laravel_health' => url('/up'),
        ],
        'documentation' => [
            'readme' => 'README.md',
            'docs_directory' => 'docs/',
            'legacy_scaffold' => 'legacy/plain-php-scaffold/',
        ],
    ]);
});
