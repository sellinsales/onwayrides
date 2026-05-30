<?php

namespace Tests\Feature\Api;

use App\Contracts\Auth\FirebaseTokenVerifier;
use App\Data\FirebaseIdentity;
use Illuminate\Support\Facades\DB;
use PDO;
use Tests\TestCase;

class OnboardingControllerTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        if (! in_array('sqlite', PDO::getAvailableDrivers(), true)) {
            $this->markTestSkipped('The pdo_sqlite driver is not installed in this PHP environment.');
        }

        config()->set('onwayrides.beta.driver_demo_access_enabled', true);

        $this->app->bind(FirebaseTokenVerifier::class, fn () => new class implements FirebaseTokenVerifier
        {
            public function verify(string $idToken): FirebaseIdentity
            {
                return new FirebaseIdentity(
                    uid: 'rider-demo-uid',
                    email: 'rider@example.com',
                    displayName: 'Rider Demo',
                    emailVerified: true,
                );
            }
        });

        $this->createOnboardingTestTables();
    }

    public function test_driver_demo_access_creates_an_approved_driver_workspace(): void
    {
        $userId = DB::table('users')->insertGetId([
            'firebase_uid' => 'rider-demo-uid',
            'full_name' => 'Rider Demo',
            'first_name' => 'Rider',
            'last_name' => 'Demo',
            'email' => 'rider@example.com',
            'country_code' => '+92',
            'role' => 'rider',
            'status' => 'active',
            'metadata' => json_encode(['auth_provider' => 'firebase']),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('cities')->insert([
            'id' => 1,
            'name' => 'Lahore',
            'slug' => 'lahore',
            'province' => 'Punjab',
            'country_code' => 'PK',
            'is_enabled' => 1,
        ]);

        DB::table('service_types')->insert([
            [
                'id' => 1,
                'name' => 'Ride',
                'slug' => 'ride',
                'category' => 'ride',
                'supports_scheduling' => 1,
                'supports_negotiation' => 0,
                'supports_driver_mode' => 1,
                'is_active' => 1,
                'sort_order' => 10,
                'created_at' => now(),
                'updated_at' => now(),
            ],
            [
                'id' => 2,
                'name' => 'Courier',
                'slug' => 'courier',
                'category' => 'delivery',
                'supports_scheduling' => 1,
                'supports_negotiation' => 0,
                'supports_driver_mode' => 1,
                'is_active' => 1,
                'sort_order' => 20,
                'created_at' => now(),
                'updated_at' => now(),
            ],
        ]);

        DB::table('vehicle_types')->insert([
            'id' => 1,
            'vehicle_category_id' => 1,
            'name' => 'Economy Car',
            'slug' => 'economy-car',
            'seats' => 4,
            'luggage_capacity' => 2,
            'is_active' => 1,
        ]);

        DB::table('vehicle_makes')->insert([
            'id' => 1,
            'name' => 'Toyota',
            'is_active' => 1,
        ]);

        DB::table('vehicle_models')->insert([
            'id' => 1,
            'vehicle_make_id' => 1,
            'name' => 'Corolla',
            'is_active' => 1,
        ]);

        $this->withHeader('Authorization', 'Bearer test-token')
            ->postJson('/api/onboarding/driver/demo-access')
            ->assertOk()
            ->assertJsonFragment([
                'status' => 'ok',
                'message' => 'Temporary demo driver access is now active.',
            ])
            ->assertJsonPath('workspace.demo_driver_access.enabled', true)
            ->assertJsonPath('workspace.driver_application.status', 'active')
            ->assertJsonPath('workspace.driver_application.onboarding_status', 'approved');

        $this->assertDatabaseHas('users', [
            'id' => $userId,
            'role' => 'rider',
        ]);

        $this->assertDatabaseHas('driver_profiles', [
            'user_id' => $userId,
            'status' => 'active',
            'onboarding_status' => 'approved',
        ]);

        $this->assertDatabaseCount('driver_service_enablements', 2);
        $this->assertDatabaseCount('driver_vehicle_assignments', 1);
    }

    private function createOnboardingTestTables(): void
    {
        DB::statement('
            CREATE TABLE users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                firebase_uid VARCHAR(191) NULL,
                full_name VARCHAR(191) NULL,
                first_name VARCHAR(191) NULL,
                last_name VARCHAR(191) NULL,
                email VARCHAR(191) NULL,
                phone VARCHAR(30) NULL,
                country_code VARCHAR(10) NULL,
                password_hash VARCHAR(255) NULL,
                role VARCHAR(50) NOT NULL DEFAULT "rider",
                status VARCHAR(50) NOT NULL DEFAULT "active",
                avatar_url VARCHAR(255) NULL,
                national_id_number VARCHAR(100) NULL,
                referral_code VARCHAR(100) NULL,
                referred_by_user_id INTEGER NULL,
                email_verified_at DATETIME NULL,
                phone_verified_at DATETIME NULL,
                last_login_at DATETIME NULL,
                metadata TEXT NULL,
                created_at DATETIME NULL,
                updated_at DATETIME NULL
            )
        ');

        DB::statement('
            CREATE TABLE cities (
                id INTEGER PRIMARY KEY,
                name VARCHAR(191) NOT NULL,
                slug VARCHAR(191) NOT NULL,
                province VARCHAR(191) NULL,
                country_code VARCHAR(10) NULL,
                is_enabled INTEGER NOT NULL DEFAULT 1
            )
        ');

        DB::statement('
            CREATE TABLE service_types (
                id INTEGER PRIMARY KEY,
                name VARCHAR(191) NOT NULL,
                slug VARCHAR(191) NOT NULL,
                category VARCHAR(50) NULL,
                supports_scheduling INTEGER NOT NULL DEFAULT 0,
                supports_negotiation INTEGER NOT NULL DEFAULT 0,
                supports_driver_mode INTEGER NOT NULL DEFAULT 1,
                is_active INTEGER NOT NULL DEFAULT 1,
                sort_order INTEGER NOT NULL DEFAULT 0,
                created_at DATETIME NULL,
                updated_at DATETIME NULL
            )
        ');

        DB::statement('
            CREATE TABLE driver_profiles (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                fleet_owner_id INTEGER NULL,
                city_id INTEGER NULL,
                driver_code VARCHAR(50) NULL,
                license_number VARCHAR(100) NULL,
                business_model VARCHAR(50) NULL,
                status VARCHAR(50) NOT NULL DEFAULT "pending",
                onboarding_status VARCHAR(50) NOT NULL DEFAULT "draft",
                is_online INTEGER NOT NULL DEFAULT 0,
                is_busy INTEGER NOT NULL DEFAULT 0,
                accepts_cash INTEGER NOT NULL DEFAULT 1,
                accepts_wallet INTEGER NOT NULL DEFAULT 0,
                accepts_card INTEGER NOT NULL DEFAULT 0,
                rating_average REAL NOT NULL DEFAULT 5,
                rating_count INTEGER NOT NULL DEFAULT 0,
                trips_completed INTEGER NOT NULL DEFAULT 0,
                wallet_hold_amount REAL NOT NULL DEFAULT 0,
                last_latitude REAL NULL,
                last_longitude REAL NULL,
                last_location_at DATETIME NULL,
                notes TEXT NULL,
                created_at DATETIME NULL,
                updated_at DATETIME NULL
            )
        ');

        DB::statement('
            CREATE TABLE vehicle_types (
                id INTEGER PRIMARY KEY,
                vehicle_category_id INTEGER NOT NULL,
                name VARCHAR(191) NOT NULL,
                slug VARCHAR(191) NOT NULL,
                seats INTEGER NULL,
                luggage_capacity INTEGER NULL,
                is_active INTEGER NOT NULL DEFAULT 1
            )
        ');

        DB::statement('
            CREATE TABLE vehicle_makes (
                id INTEGER PRIMARY KEY,
                name VARCHAR(191) NOT NULL,
                is_active INTEGER NOT NULL DEFAULT 1
            )
        ');

        DB::statement('
            CREATE TABLE vehicle_models (
                id INTEGER PRIMARY KEY,
                vehicle_make_id INTEGER NOT NULL,
                name VARCHAR(191) NOT NULL,
                is_active INTEGER NOT NULL DEFAULT 1
            )
        ');

        DB::statement('
            CREATE TABLE vehicles (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                fleet_owner_id INTEGER NULL,
                registered_owner_user_id INTEGER NULL,
                vehicle_type_id INTEGER NOT NULL,
                vehicle_make_id INTEGER NULL,
                vehicle_model_id INTEGER NULL,
                plate_number VARCHAR(50) NOT NULL,
                color VARCHAR(50) NULL,
                year_of_manufacture INTEGER NULL,
                seats INTEGER NULL,
                fuel_type VARCHAR(50) NOT NULL DEFAULT "petrol",
                status VARCHAR(50) NOT NULL DEFAULT "pending",
                insurance_expiry_date DATE NULL,
                inspection_expiry_date DATE NULL,
                metadata TEXT NULL,
                created_at DATETIME NULL,
                updated_at DATETIME NULL
            )
        ');

        DB::statement('
            CREATE TABLE driver_vehicle_assignments (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                driver_profile_id INTEGER NOT NULL,
                vehicle_id INTEGER NOT NULL,
                assigned_by_user_id INTEGER NULL,
                starts_at DATETIME NOT NULL,
                ends_at DATETIME NULL,
                is_current INTEGER NOT NULL DEFAULT 1,
                notes TEXT NULL,
                created_at DATETIME NULL,
                updated_at DATETIME NULL
            )
        ');

        DB::statement('
            CREATE TABLE driver_service_enablements (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                driver_profile_id INTEGER NOT NULL,
                service_type_id INTEGER NOT NULL,
                is_enabled INTEGER NOT NULL DEFAULT 1,
                approved_by_user_id INTEGER NULL,
                created_at DATETIME NULL,
                updated_at DATETIME NULL
            )
        ');

        DB::statement('
            CREATE TABLE driver_documents (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                driver_profile_id INTEGER NOT NULL,
                document_type VARCHAR(50) NOT NULL,
                status VARCHAR(50) NOT NULL DEFAULT "pending",
                expiry_date DATE NULL,
                reviewed_at DATETIME NULL,
                rejection_reason TEXT NULL,
                created_at DATETIME NULL,
                updated_at DATETIME NULL
            )
        ');

        DB::statement('
            CREATE TABLE fleet_owners (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                city_id INTEGER NULL,
                fleet_code VARCHAR(50) NULL,
                company_name VARCHAR(191) NULL,
                business_model VARCHAR(50) NULL,
                status VARCHAR(50) NOT NULL DEFAULT "pending",
                support_email VARCHAR(191) NULL,
                support_phone VARCHAR(30) NULL,
                notes TEXT NULL
            )
        ');
    }
}
