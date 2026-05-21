<?php

namespace App\Services\Auth;

use App\Data\FirebaseIdentity;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class FirebaseUserSyncService
{
    public function syncFromIdentity(FirebaseIdentity $identity, array $context = [], bool $touchLogin = true): User
    {
        $requestedRole = $this->resolveRequestedRole($context['role'] ?? null);
        $user = $this->findExistingUser($identity);
        $isNewUser = $user === null;

        $user ??= new User();

        if ($isNewUser) {
            $user->role = $requestedRole;
            $user->status = $this->defaultStatusForRole($requestedRole);
            $user->country_code = $this->resolveCountryCode($identity->phoneNumber);
        }

        $fullName = $this->resolveDisplayName($identity, $context['full_name'] ?? null);
        [$firstName, $lastName] = $this->splitName($fullName);

        $user->firebase_uid = $identity->uid;
        $user->full_name = $fullName;
        $user->first_name = $firstName;
        $user->last_name = $lastName;

        if ($identity->email !== null) {
            $user->email = $identity->email;
        }

        if ($identity->phoneNumber !== null) {
            $user->phone = $identity->phoneNumber;
            $user->phone_verified_at ??= now();
            $user->country_code = $this->resolveCountryCode($identity->phoneNumber);
        }

        if ($identity->photoUrl !== null) {
            $user->avatar_url = $identity->photoUrl;
        }

        if ($identity->emailVerified) {
            $user->email_verified_at ??= now();
        }

        if ($touchLogin) {
            $user->last_login_at = now();
        }

        $metadata = is_array($user->metadata) ? $user->metadata : [];
        $metadata['auth_provider'] = 'firebase';
        $metadata['beta_mode'] = config('onwayrides.beta.mode');

        if (isset($context['platform']) && is_string($context['platform']) && trim($context['platform']) !== '') {
            $metadata['last_sign_in_platform'] = trim($context['platform']);
        }

        $user->metadata = $metadata;
        $user->save();

        $this->ensureRoleProfileExists($user);

        return $user->fresh();
    }

    private function findExistingUser(FirebaseIdentity $identity): ?User
    {
        $user = User::query()
            ->where('firebase_uid', $identity->uid)
            ->first();

        if ($user !== null) {
            return $user;
        }

        if ($identity->email !== null) {
            $user = User::query()
                ->whereNull('firebase_uid')
                ->where('email', $identity->email)
                ->first();

            if ($user !== null) {
                return $user;
            }
        }

        if ($identity->phoneNumber !== null) {
            return User::query()
                ->whereNull('firebase_uid')
                ->where('phone', $identity->phoneNumber)
                ->first();
        }

        return null;
    }

    private function resolveRequestedRole(mixed $role): string
    {
        $allowedRoles = ['rider', 'driver', 'fleet_owner', 'merchant'];

        return is_string($role) && in_array($role, $allowedRoles, true)
            ? $role
            : 'rider';
    }

    private function defaultStatusForRole(string $role): string
    {
        return in_array($role, ['driver', 'fleet_owner', 'merchant'], true)
            ? 'pending'
            : 'active';
    }

    private function resolveDisplayName(FirebaseIdentity $identity, mixed $requestFullName): string
    {
        if (is_string($requestFullName) && trim($requestFullName) !== '') {
            return trim($requestFullName);
        }

        if ($identity->displayName !== null && trim($identity->displayName) !== '') {
            return trim($identity->displayName);
        }

        if ($identity->email !== null && trim($identity->email) !== '') {
            return Str::headline((string) Str::before($identity->email, '@'));
        }

        return 'OnWay User';
    }

    private function splitName(string $fullName): array
    {
        $segments = preg_split('/\s+/', trim($fullName)) ?: [];
        $firstName = $segments[0] ?? $fullName;
        $lastName = count($segments) > 1 ? implode(' ', array_slice($segments, 1)) : null;

        return [$firstName, $lastName];
    }

    private function resolveCountryCode(?string $phoneNumber): string
    {
        if ($phoneNumber === null || $phoneNumber === '') {
            return (string) config('onwayrides.default_country_code', '+92');
        }

        if (preg_match('/^(\+\d{1,4})/', $phoneNumber, $matches) === 1) {
            return $matches[1];
        }

        return (string) config('onwayrides.default_country_code', '+92');
    }

    private function ensureRoleProfileExists(User $user): void
    {
        $now = now();

        if ($user->role === 'rider') {
            $exists = DB::table('rider_profiles')
                ->where('user_id', $user->id)
                ->exists();

            if (! $exists) {
                DB::table('rider_profiles')->insert([
                    'user_id' => $user->id,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }

            return;
        }

        if ($user->role === 'driver') {
            $exists = DB::table('driver_profiles')
                ->where('user_id', $user->id)
                ->exists();

            if (! $exists) {
                DB::table('driver_profiles')->insert([
                    'user_id' => $user->id,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }
        }
    }
}
