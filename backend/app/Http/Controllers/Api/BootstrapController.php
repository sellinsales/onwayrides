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
            'beta' => config('onwayrides.beta'),
            'auth' => [
                'provider' => 'firebase',
                'login_endpoint' => route('api.auth.login', absolute: false),
                'me_endpoint' => route('api.auth.me', absolute: false),
                'onboarding_endpoint' => route('api.auth.onboarding', absolute: false),
            ],
            'marketing' => [
                'whatsapp_business_number' => config('onwayrides.whatsapp_business_number'),
                'whatsapp_channel_url' => config('onwayrides.whatsapp_channel_url'),
                'admin_contacts_endpoint' => route('api.admin.marketing.contacts', absolute: false),
                'admin_contacts_export_endpoint' => route('api.admin.marketing.contacts.export', absolute: false),
            ],
            'admin_operations' => [
                'driver_applications_endpoint' => route('api.admin.drivers.applications.index', absolute: false),
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
