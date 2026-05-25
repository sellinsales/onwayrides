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

    public function test_auth_onboarding_requires_a_firebase_token(): void
    {
        $this->patchJson('/api/auth/onboarding', [
            'country_code' => '+92',
            'phone' => '3001234567',
            'accept_privacy_policy' => true,
            'accept_terms' => true,
        ])
            ->assertUnauthorized()
            ->assertJsonFragment([
                'status' => 'error',
                'message' => 'A Firebase ID token is required.',
            ]);
    }

    public function test_admin_marketing_contacts_require_a_firebase_token(): void
    {
        $this->getJson('/api/admin/marketing/contacts')
            ->assertUnauthorized()
            ->assertJsonFragment([
                'status' => 'error',
                'message' => 'A Firebase ID token is required.',
            ]);
    }

    public function test_device_token_registration_requires_a_firebase_token(): void
    {
        $this->postJson('/api/devices/token', [
            'token' => 'sample-token',
            'platform' => 'android',
        ])
            ->assertUnauthorized()
            ->assertJsonFragment([
                'status' => 'error',
                'message' => 'A Firebase ID token is required.',
            ]);
    }

    public function test_device_token_removal_requires_a_firebase_token(): void
    {
        $this->deleteJson('/api/devices/token', [
            'token' => 'sample-token',
        ])
            ->assertUnauthorized()
            ->assertJsonFragment([
                'status' => 'error',
                'message' => 'A Firebase ID token is required.',
            ]);
    }

    public function test_admin_driver_applications_require_a_firebase_token(): void
    {
        $this->getJson('/api/admin/drivers/applications')
            ->assertUnauthorized()
            ->assertJsonFragment([
                'status' => 'error',
                'message' => 'A Firebase ID token is required.',
            ]);
    }

    public function test_admin_driver_document_review_requires_a_firebase_token(): void
    {
        $this->patchJson('/api/admin/driver-documents/1/status', [
            'status' => 'approved',
        ])
            ->assertUnauthorized()
            ->assertJsonFragment([
                'status' => 'error',
                'message' => 'A Firebase ID token is required.',
            ]);
    }
}
