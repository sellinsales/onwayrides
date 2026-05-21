<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Support\Env;
use App\Support\Request;

final class HealthController
{
    /**
     * @param array<string, string> $params
     * @return array{status:int,data:array<string,mixed>}
     */
    public function index(Request $request, array $params = []): array
    {
        return [
            'status' => 200,
            'data' => [
                'success' => true,
                'message' => 'OnWay Rides API is running.',
                'app' => [
                    'name' => Env::get('APP_NAME', 'OnWayRides'),
                    'env' => Env::get('APP_ENV', 'production'),
                    'url' => Env::get('APP_URL'),
                ],
            ],
        ];
    }
}
