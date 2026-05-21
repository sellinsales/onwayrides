<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Support\Database;
use App\Support\Request;

final class BootstrapController
{
    /**
     * @param array<string, string> $params
     * @return array{status:int,data:array<string,mixed>}
     */
    public function index(Request $request, array $params = []): array
    {
        $pdo = Database::connection();

        $settings = $pdo->query(
            "SELECT `group`, `key`, value_text, value_json
             FROM system_settings
             WHERE is_public = 1
             ORDER BY `group`, `key`"
        )->fetchAll();

        $cities = $pdo->query(
            "SELECT id, name, slug, province, country_code
             FROM cities
             WHERE is_enabled = 1
             ORDER BY name"
        )->fetchAll();

        $services = $pdo->query(
            "SELECT id, name, slug, category, description, supports_negotiation, supports_scheduling
             FROM service_types
             WHERE is_active = 1
             ORDER BY sort_order, name"
        )->fetchAll();

        return [
            'status' => 200,
            'data' => [
                'success' => true,
                'data' => [
                    'settings' => $settings,
                    'cities' => $cities,
                    'services' => $services,
                ],
            ],
        ];
    }
}
