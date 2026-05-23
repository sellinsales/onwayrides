<?php

return [
    'api_version' => env('ONWAYRIDES_API_VERSION', 'v1'),
    'frontend_url' => env('FRONTEND_URL', 'https://onwayrides.com'),
    'admin_url' => env('ADMIN_URL', 'https://admin.onwayrides.com'),
    'support_email' => env('SUPPORT_EMAIL', 'support@onwayrides.com'),
    'support_phone' => env('SUPPORT_PHONE', '+92-300-0000000'),
    'whatsapp_business_number' => env('WHATSAPP_BUSINESS_NUMBER', '+46793000786'),
    'whatsapp_channel_url' => env('WHATSAPP_CHANNEL_URL', ''),
    'default_country_code' => env('DEFAULT_COUNTRY_CODE', '+92'),
    'default_currency' => env('DEFAULT_CURRENCY', 'PKR'),
    'beta' => [
        'mode' => 'free-beta',
        'daily_rides_limit' => 3,
        'full_access_requires_driver_approval' => true,
    ],

    'platform' => [
        'name' => 'OnWay Rides',
        'tagline' => 'Multi-service mobility, delivery, and fleet platform',
        'roles' => [
            'admin',
            'rider',
            'driver',
            'fleet_owner',
            'merchant',
            'support',
        ],
        'service_categories' => [
            'ride',
            'delivery',
            'rental',
            'food',
            'school',
            'airport',
            'prebooking',
        ],
    ],

    'storage' => [
        'private_root' => 'app/private',
        'driver_documents' => 'app/private/driver-documents',
        'vehicle_documents' => 'app/private/vehicle-documents',
        'profile_photos' => 'app/private/profile-photos',
        'complaint_attachments' => 'app/private/complaint-attachments',
    ],
];
