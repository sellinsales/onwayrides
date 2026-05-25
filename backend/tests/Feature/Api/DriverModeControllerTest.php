<?php

namespace Tests\Feature\Api;

use App\Contracts\Auth\FirebaseTokenVerifier;
use App\Data\FirebaseIdentity;
use Illuminate\Support\Facades\DB;
use PDO;
use Tests\TestCase;

class DriverModeControllerTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        if (! in_array('sqlite', PDO::getAvailableDrivers(), true)) {
            $this->markTestSkipped('The pdo_sqlite driver is not installed in this PHP environment.');
        }

        $this->app->bind(FirebaseTokenVerifier::class, fn () => new class implements FirebaseTokenVerifier
        {
            public function verify(string $idToken): FirebaseIdentity
            {
                return new FirebaseIdentity(
                    uid: 'driver-test-uid',
                    email: 'driver@example.com',
                    displayName: 'Dispatch Driver',
                    emailVerified: true,
                );
            }
        });

        $this->createDriverModeTestTables();
    }

    public function test_driver_mode_can_enable_newly_selected_services(): void
    {
        $userId = DB::table('users')->insertGetId([
            'firebase_uid' => 'driver-test-uid',
            'full_name' => 'Dispatch Driver',
            'first_name' => 'Dispatch',
            'last_name' => 'Driver',
            'email' => 'driver@example.com',
            'country_code' => '+92',
            'role' => 'driver',
            'status' => 'active',
            'metadata' => json_encode(['auth_provider' => 'firebase']),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $driverProfileId = DB::table('driver_profiles')->insertGetId([
            'user_id' => $userId,
            'driver_code' => 'DRV-TEST01',
            'city_id' => 1,
            'status' => 'active',
            'onboarding_status' => 'approved',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('service_types')->insert([
            [
                'id' => 1,
                'name' => 'Ride',
                'slug' => 'ride',
                'is_active' => 1,
                'created_at' => now(),
                'updated_at' => now(),
            ],
            [
                'id' => 2,
                'name' => 'Courier',
                'slug' => 'courier',
                'is_active' => 1,
                'created_at' => now(),
                'updated_at' => now(),
            ],
        ]);

        DB::table('driver_service_enablements')->insert([
            'driver_profile_id' => $driverProfileId,
            'service_type_id' => 1,
            'is_enabled' => 1,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->withHeader('Authorization', 'Bearer test-token')
            ->patchJson('/api/driver/mode', [
                'is_online' => true,
                'service_type_ids' => [1, 2],
            ])
            ->assertOk()
            ->assertJsonFragment([
                'status' => 'ok',
                'message' => 'Driver mode is now online.',
            ]);

        $this->assertDatabaseHas('driver_profiles', [
            'id' => $driverProfileId,
            'is_online' => 1,
        ]);

        $this->assertDatabaseHas('driver_service_enablements', [
            'driver_profile_id' => $driverProfileId,
            'service_type_id' => 1,
            'is_enabled' => 1,
        ]);

        $this->assertDatabaseHas('driver_service_enablements', [
            'driver_profile_id' => $driverProfileId,
            'service_type_id' => 2,
            'is_enabled' => 1,
        ]);
    }

    private function createDriverModeTestTables(): void
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
            CREATE TABLE driver_profiles (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                driver_code VARCHAR(50) NULL,
                city_id INTEGER NULL,
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
                license_number VARCHAR(100) NULL,
                business_model VARCHAR(50) NULL,
                notes TEXT NULL,
                created_at DATETIME NULL,
                updated_at DATETIME NULL
            )
        ');

        DB::statement('
            CREATE TABLE service_types (
                id INTEGER PRIMARY KEY,
                name VARCHAR(191) NOT NULL,
                slug VARCHAR(191) NOT NULL,
                is_active INTEGER NOT NULL DEFAULT 1,
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
                created_at DATETIME NULL,
                updated_at DATETIME NULL
            )
        ');
    }
}
