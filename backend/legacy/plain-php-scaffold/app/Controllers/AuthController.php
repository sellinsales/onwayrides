<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Support\Database;
use App\Support\Request;
use PDO;
use RuntimeException;

final class AuthController
{
    /**
     * @param array<string, string> $params
     * @return array{status:int,data:array<string,mixed>}
     */
    public function sync(Request $request, array $params = []): array
    {
        $firebaseUid = trim((string) $request->input('firebase_uid', ''));
        $fullName = trim((string) $request->input('full_name', ''));
        $email = trim((string) $request->input('email', ''));
        $phone = trim((string) $request->input('phone', ''));
        $role = trim((string) $request->input('role', 'rider'));
        $cityId = $request->input('city_id');

        if ($firebaseUid === '' || $fullName === '') {
            return [
                'status' => 422,
                'data' => [
                    'success' => false,
                    'message' => 'firebase_uid and full_name are required.',
                ],
            ];
        }

        $allowedRoles = ['rider', 'driver', 'fleet_owner'];
        if (!in_array($role, $allowedRoles, true)) {
            $role = 'rider';
        }

        $status = $role === 'rider' ? 'active' : 'pending';
        $pdo = Database::connection();
        $pdo->beginTransaction();

        try {
            $user = $this->findUser($pdo, $firebaseUid, $email, $phone);

            if ($user === null) {
                $insert = $pdo->prepare(
                    "INSERT INTO users
                    (firebase_uid, full_name, first_name, last_name, email, phone, role, status, phone_verified_at, email_verified_at)
                    VALUES
                    (:firebase_uid, :full_name, :first_name, :last_name, :email, :phone, :role, :status, :phone_verified_at, :email_verified_at)"
                );

                [$firstName, $lastName] = $this->splitName($fullName);

                $insert->execute([
                    'firebase_uid' => $firebaseUid,
                    'full_name' => $fullName,
                    'first_name' => $firstName,
                    'last_name' => $lastName,
                    'email' => $email !== '' ? $email : null,
                    'phone' => $phone !== '' ? $phone : null,
                    'role' => $role,
                    'status' => $status,
                    'phone_verified_at' => $phone !== '' ? date('Y-m-d H:i:s') : null,
                    'email_verified_at' => $email !== '' ? date('Y-m-d H:i:s') : null,
                ]);

                $userId = (int) $pdo->lastInsertId();
            } else {
                $userId = (int) $user['id'];

                [$firstName, $lastName] = $this->splitName($fullName);
                $update = $pdo->prepare(
                    "UPDATE users
                     SET firebase_uid = :firebase_uid,
                         full_name = :full_name,
                         first_name = :first_name,
                         last_name = :last_name,
                         email = :email,
                         phone = :phone,
                         role = CASE WHEN role = 'admin' THEN role ELSE :role END,
                         status = CASE WHEN role = 'admin' THEN status ELSE :status END,
                         last_login_at = NOW()
                     WHERE id = :id"
                );

                $update->execute([
                    'firebase_uid' => $firebaseUid,
                    'full_name' => $fullName,
                    'first_name' => $firstName,
                    'last_name' => $lastName,
                    'email' => $email !== '' ? $email : null,
                    'phone' => $phone !== '' ? $phone : null,
                    'role' => $role,
                    'status' => $status,
                    'id' => $userId,
                ]);
            }

            $this->ensureWallet($pdo, $userId);
            $this->ensureNotificationPreferences($pdo, $userId);
            $profile = $this->ensureProfile($pdo, $userId, $role, $fullName, $cityId);

            $freshUser = $pdo->prepare("SELECT id, firebase_uid, full_name, email, phone, role, status FROM users WHERE id = :id");
            $freshUser->execute(['id' => $userId]);

            $pdo->commit();

            return [
                'status' => 200,
                'data' => [
                    'success' => true,
                    'message' => 'User synced successfully.',
                    'data' => [
                        'user' => $freshUser->fetch(),
                        'profile' => $profile,
                        'todo' => 'Replace this sync flow with verified Firebase ID token validation before production launch.',
                    ],
                ],
            ];
        } catch (\Throwable $exception) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }

            throw $exception;
        }
    }

    private function findUser(PDO $pdo, string $firebaseUid, string $email, string $phone): ?array
    {
        $statement = $pdo->prepare(
            "SELECT * FROM users
             WHERE firebase_uid = :firebase_uid
                OR (:email <> '' AND email = :email)
                OR (:phone <> '' AND phone = :phone)
             LIMIT 1"
        );
        $statement->execute([
            'firebase_uid' => $firebaseUid,
            'email' => $email,
            'phone' => $phone,
        ]);

        $user = $statement->fetch();
        return $user === false ? null : $user;
    }

    /**
     * @return array{0:string,1:?string}
     */
    private function splitName(string $fullName): array
    {
        $parts = preg_split('/\s+/', trim($fullName)) ?: [];
        $firstName = $parts[0] ?? $fullName;
        $lastName = count($parts) > 1 ? implode(' ', array_slice($parts, 1)) : null;

        return [$firstName, $lastName];
    }

    private function ensureWallet(PDO $pdo, int $userId): void
    {
        $statement = $pdo->prepare(
            "INSERT INTO wallets (user_id, wallet_type, currency, balance, hold_balance, status)
             VALUES (:user_id, 'main', 'PKR', 0, 0, 'active')
             ON DUPLICATE KEY UPDATE status = VALUES(status)"
        );
        $statement->execute(['user_id' => $userId]);
    }

    private function ensureNotificationPreferences(PDO $pdo, int $userId): void
    {
        $statement = $pdo->prepare(
            "INSERT INTO notification_preferences (user_id, push_enabled, sms_enabled, email_enabled, marketing_enabled)
             VALUES (:user_id, 1, 1, 1, 0)
             ON DUPLICATE KEY UPDATE user_id = user_id"
        );
        $statement->execute(['user_id' => $userId]);
    }

    /**
     * @return array<string, mixed>
     */
    private function ensureProfile(PDO $pdo, int $userId, string $role, string $fullName, mixed $cityId): array
    {
        return match ($role) {
            'driver' => $this->ensureDriverProfile($pdo, $userId, $cityId),
            'fleet_owner' => $this->ensureFleetOwner($pdo, $userId, $fullName, $cityId),
            default => $this->ensureRiderProfile($pdo, $userId),
        };
    }

    /**
     * @return array<string, mixed>
     */
    private function ensureRiderProfile(PDO $pdo, int $userId): array
    {
        $statement = $pdo->prepare(
            "INSERT INTO rider_profiles (user_id)
             VALUES (:user_id)
             ON DUPLICATE KEY UPDATE user_id = user_id"
        );
        $statement->execute(['user_id' => $userId]);

        $profile = $pdo->prepare("SELECT * FROM rider_profiles WHERE user_id = :user_id LIMIT 1");
        $profile->execute(['user_id' => $userId]);
        return $profile->fetch() ?: [];
    }

    /**
     * @return array<string, mixed>
     */
    private function ensureDriverProfile(PDO $pdo, int $userId, mixed $cityId): array
    {
        $statement = $pdo->prepare(
            "INSERT INTO driver_profiles (user_id, city_id, status, onboarding_status)
             VALUES (:user_id, :city_id, 'pending', 'draft')
             ON DUPLICATE KEY UPDATE city_id = COALESCE(VALUES(city_id), city_id)"
        );
        $statement->execute([
            'user_id' => $userId,
            'city_id' => is_numeric((string) $cityId) ? (int) $cityId : null,
        ]);

        $profile = $pdo->prepare("SELECT * FROM driver_profiles WHERE user_id = :user_id LIMIT 1");
        $profile->execute(['user_id' => $userId]);
        return $profile->fetch() ?: [];
    }

    /**
     * @return array<string, mixed>
     */
    private function ensureFleetOwner(PDO $pdo, int $userId, string $fullName, mixed $cityId): array
    {
        $cityCode = 'GEN';
        $numericCityId = is_numeric((string) $cityId) ? (int) $cityId : null;

        if ($numericCityId !== null) {
            $city = $pdo->prepare("SELECT slug FROM cities WHERE id = :id LIMIT 1");
            $city->execute(['id' => $numericCityId]);
            $row = $city->fetch();
            if (is_array($row) && isset($row['slug'])) {
                $cityCode = strtoupper(substr((string) $row['slug'], 0, 3));
            }
        }

        $fleetCode = sprintf('ONW-%s-%04d', $cityCode, $userId);

        $statement = $pdo->prepare(
            "INSERT INTO fleet_owners (user_id, city_id, fleet_code, company_name, status)
             VALUES (:user_id, :city_id, :fleet_code, :company_name, 'pending')
             ON DUPLICATE KEY UPDATE
                city_id = COALESCE(VALUES(city_id), city_id),
                company_name = VALUES(company_name)"
        );
        $statement->execute([
            'user_id' => $userId,
            'city_id' => $numericCityId,
            'fleet_code' => $fleetCode,
            'company_name' => $fullName . ' Fleet',
        ]);

        $profile = $pdo->prepare("SELECT * FROM fleet_owners WHERE user_id = :user_id LIMIT 1");
        $profile->execute(['user_id' => $userId]);
        return $profile->fetch() ?: [];
    }
}
