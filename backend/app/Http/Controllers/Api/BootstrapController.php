<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;

class BootstrapController extends Controller
{
    public function __invoke(): JsonResponse
    {
        return response()->json([
            'platform' => [
                'name' => config('onwayrides.platform.name'),
                'tagline' => config('onwayrides.platform.tagline'),
                'api_version' => config('onwayrides.api_version'),
                'frontend_url' => config('onwayrides.frontend_url'),
                'admin_url' => config('onwayrides.admin_url'),
            ],
            'defaults' => [
                'country_code' => config('onwayrides.default_country_code'),
                'currency' => config('onwayrides.default_currency'),
                'timezone' => config('app.timezone'),
            ],
            'support' => [
                'email' => config('onwayrides.support_email'),
                'phone' => config('onwayrides.support_phone'),
            ],
            'roles' => config('onwayrides.platform.roles'),
            'service_categories' => config('onwayrides.platform.service_categories'),
            'storage' => [
                'strategy' => 'server-local',
                'sensitive_documents' => 'private',
                'public_assets' => 'public',
            ],
        ]);
    }
}
