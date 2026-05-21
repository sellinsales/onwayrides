<?php

namespace Tests\Feature\Api;

use Tests\TestCase;

class PlatformApiTest extends TestCase
{
    public function test_health_endpoint_returns_backend_status_payload(): void
    {
        $this->getJson('/api/health')
            ->assertOk()
            ->assertJsonStructure([
                'status',
                'app',
                'environment',
                'api_version',
                'timestamp',
                'database' => [
                    'connection',
                    'status',
                ],
            ]);
    }

    public function test_bootstrap_endpoint_returns_platform_metadata(): void
    {
        $this->getJson('/api/bootstrap')
            ->assertOk()
            ->assertJsonFragment([
                'name' => 'OnWay Rides',
                'strategy' => 'server-local',
            ]);
    }

    public function test_auth_me_requires_a_firebase_token(): void
    {
        $this->getJson('/api/auth/me')
            ->assertUnauthorized()
            ->assertJsonFragment([
                'status' => 'error',
                'message' => 'A Firebase ID token is required.',
            ]);
    }
}
