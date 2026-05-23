<?php

namespace App\Http\Controllers\Api;

use App\Contracts\Auth\FirebaseTokenVerifier;
use App\Exceptions\FirebaseAuthenticationException;
use App\Exceptions\FirebaseConfigurationException;
use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\Auth\FirebaseUserSyncService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AuthController extends Controller
{
    public function login(
        Request $request,
        FirebaseTokenVerifier $tokenVerifier,
        FirebaseUserSyncService $userSyncService
    ): JsonResponse {
        $payload = $request->validate([
            'full_name' => ['nullable', 'string', 'max:191'],
            'role' => ['nullable', 'in:rider,driver,fleet_owner,merchant'],
            'platform' => ['nullable', 'string', 'max:40'],
        ]);

        return $this->authenticateRequest($request, $payload, $tokenVerifier, $userSyncService, true);
    }

    public function me(
        Request $request,
        FirebaseTokenVerifier $tokenVerifier,
        FirebaseUserSyncService $userSyncService
    ): JsonResponse {
        return $this->authenticateRequest($request, [], $tokenVerifier, $userSyncService, false);
    }

    public function completeOnboarding(
        Request $request,
        FirebaseTokenVerifier $tokenVerifier,
        FirebaseUserSyncService $userSyncService
    ): JsonResponse {
        $payload = $request->validate([
            'full_name' => ['nullable', 'string', 'max:191'],
            'country_code' => ['required', 'string', 'regex:/^\+?[0-9]{1,4}$/'],
            'phone' => ['required', 'string', 'max:30'],
            'accept_privacy_policy' => ['accepted'],
            'accept_terms' => ['accepted'],
            'sms_marketing_opt_in' => ['nullable', 'boolean'],
            'whatsapp_marketing_opt_in' => ['nullable', 'boolean'],
        ]);

        try {
            $identity = $tokenVerifier->verify($this->extractIdToken($request));
            $user = $userSyncService->syncFromIdentity($identity, [], false);
        } catch (FirebaseConfigurationException $exception) {
            return response()->json([
                'status' => 'error',
                'message' => $exception->getMessage(),
            ], 503);
        } catch (FirebaseAuthenticationException $exception) {
            return response()->json([
                'status' => 'error',
                'message' => $exception->getMessage(),
            ], 401);
        }

        $countryCode = $this->normalizeCountryCode($payload['country_code']);
        $normalizedPhone = $this->normalizePhone($payload['phone'], $countryCode);

        if (strlen(preg_replace('/\D+/', '', $normalizedPhone) ?? '') < 10) {
            return response()->json([
                'status' => 'error',
                'message' => 'Please enter a valid phone number.',
                'errors' => [
                    'phone' => [
                        'Please enter a valid phone number.',
                    ],
                ],
            ], 422);
        }

        $existingPhoneOwner = User::query()
            ->where('phone', $normalizedPhone)
            ->whereKeyNot($user->id)
            ->first();

        if ($existingPhoneOwner !== null) {
            return response()->json([
                'status' => 'error',
                'message' => 'That phone number is already linked to another OnWay Rides account.',
                'errors' => [
                    'phone' => [
                        'That phone number is already linked to another OnWay Rides account.',
                    ],
                ],
            ], 422);
        }

        if (isset($payload['full_name']) && trim((string) $payload['full_name']) !== '') {
            $fullName = trim((string) $payload['full_name']);
            [$firstName, $lastName] = $this->splitName($fullName);
            $user->full_name = $fullName;
            $user->first_name = $firstName;
            $user->last_name = $lastName;
        }

        if ($user->phone !== $normalizedPhone) {
            $user->phone = $normalizedPhone;
            $user->phone_verified_at = null;
        }

        $user->country_code = $countryCode;

        $metadata = is_array($user->metadata) ? $user->metadata : [];
        $metadata['auth_provider'] = $metadata['auth_provider'] ?? 'firebase';
        $metadata['beta_mode'] = config('onwayrides.beta.mode');
        $metadata['privacy_policy_accepted_at'] = now()->toIso8601String();
        $metadata['terms_of_service_accepted_at'] = now()->toIso8601String();
        $metadata['sms_marketing_opt_in'] = (bool) ($payload['sms_marketing_opt_in'] ?? false);
        $metadata['whatsapp_marketing_opt_in'] = (bool) ($payload['whatsapp_marketing_opt_in'] ?? false);
        $metadata['phone_collection_source'] = 'profile_completion';
        $metadata['phone_collected_at'] = now()->toIso8601String();
        $metadata['profile_completed_at'] = now()->toIso8601String();

        if ($identity->phoneNumber !== null && $identity->phoneNumber === $normalizedPhone) {
            $user->phone_verified_at ??= now();
            $metadata['phone_verification_source'] = 'firebase-phone';
        } else {
            $user->phone_verified_at = null;
            $metadata['phone_verification_source'] = 'pending-otp';
        }

        $user->metadata = $metadata;
        $user->save();

        $user = $user->fresh();

        return response()->json([
            'status' => 'ok',
            'message' => 'Phone number and consent preferences saved.',
            'auth' => [
                'provider' => 'firebase',
                'guard' => 'firebase-id-token',
            ],
            'beta' => [
                'mode' => config('onwayrides.beta.mode'),
                'daily_rides_limit' => config('onwayrides.beta.daily_rides_limit'),
                'full_access_requires_driver_approval' => config('onwayrides.beta.full_access_requires_driver_approval'),
            ],
            'requirements' => $this->buildRequirements($user),
            'consents' => $this->buildConsents($user),
            'user' => $this->serializeUser($user),
        ]);
    }

    private function authenticateRequest(
        Request $request,
        array $context,
        FirebaseTokenVerifier $tokenVerifier,
        FirebaseUserSyncService $userSyncService,
        bool $touchLogin
    ): JsonResponse {
        try {
            $user = $this->authenticateUser($request, $context, $tokenVerifier, $userSyncService, $touchLogin);
        } catch (FirebaseConfigurationException $exception) {
            return response()->json([
                'status' => 'error',
                'message' => $exception->getMessage(),
            ], 503);
        } catch (FirebaseAuthenticationException $exception) {
            return response()->json([
                'status' => 'error',
                'message' => $exception->getMessage(),
            ], 401);
        }

        return response()->json([
            'status' => 'ok',
            'message' => 'Firebase identity verified and local user synced.',
            'auth' => [
                'provider' => 'firebase',
                'guard' => 'firebase-id-token',
            ],
            'beta' => [
                'mode' => config('onwayrides.beta.mode'),
                'daily_rides_limit' => config('onwayrides.beta.daily_rides_limit'),
                'full_access_requires_driver_approval' => config('onwayrides.beta.full_access_requires_driver_approval'),
            ],
            'requirements' => $this->buildRequirements($user),
            'consents' => $this->buildConsents($user),
            'user' => $this->serializeUser($user),
        ]);
    }

    private function authenticateUser(
        Request $request,
        array $context,
        FirebaseTokenVerifier $tokenVerifier,
        FirebaseUserSyncService $userSyncService,
        bool $touchLogin
    ): User {
        $identity = $tokenVerifier->verify($this->extractIdToken($request));

        return $userSyncService->syncFromIdentity($identity, $context, $touchLogin);
    }

    private function extractIdToken(Request $request): string
    {
        $bearerToken = $request->bearerToken();
        if (is_string($bearerToken) && trim($bearerToken) !== '') {
            return trim($bearerToken);
        }

        $requestToken = $request->string('id_token')->trim()->value();
        if ($requestToken !== '') {
            return $requestToken;
        }

        throw new FirebaseAuthenticationException('A Firebase ID token is required.');
    }

    private function serializeUser(User $user): array
    {
        return [
            'id' => $user->id,
            'firebase_uid' => $user->firebase_uid,
            'full_name' => $user->full_name,
            'first_name' => $user->first_name,
            'last_name' => $user->last_name,
            'email' => $user->email,
            'phone' => $user->phone,
            'country_code' => $user->country_code,
            'role' => $user->role,
            'status' => $user->status,
            'avatar_url' => $user->avatar_url,
            'email_verified_at' => optional($user->email_verified_at)->toIso8601String(),
            'phone_verified_at' => optional($user->phone_verified_at)->toIso8601String(),
            'last_login_at' => optional($user->last_login_at)->toIso8601String(),
            'metadata' => $user->metadata ?? [],
        ];
    }

    private function buildRequirements(User $user): array
    {
        $metadata = is_array($user->metadata) ? $user->metadata : [];
        $needsPhone = blank($user->phone) || blank($user->country_code);
        $needsPhoneVerification = ! $needsPhone && blank($user->phone_verified_at);
        $needsPrivacyAcceptance = empty($metadata['privacy_policy_accepted_at']);
        $needsTermsAcceptance = empty($metadata['terms_of_service_accepted_at']);

        return [
            'needs_phone_number' => $needsPhone,
            'needs_phone_verification' => $needsPhoneVerification,
            'needs_privacy_acceptance' => $needsPrivacyAcceptance,
            'needs_terms_acceptance' => $needsTermsAcceptance,
            'profile_complete' => ! $needsPhone && ! $needsPhoneVerification && ! $needsPrivacyAcceptance && ! $needsTermsAcceptance,
        ];
    }

    private function buildConsents(User $user): array
    {
        $metadata = is_array($user->metadata) ? $user->metadata : [];

        return [
            'sms_marketing_opt_in' => (bool) ($metadata['sms_marketing_opt_in'] ?? false),
            'whatsapp_marketing_opt_in' => (bool) ($metadata['whatsapp_marketing_opt_in'] ?? false),
            'privacy_policy_accepted_at' => $metadata['privacy_policy_accepted_at'] ?? null,
            'terms_of_service_accepted_at' => $metadata['terms_of_service_accepted_at'] ?? null,
        ];
    }

    private function normalizeCountryCode(string $value): string
    {
        $digits = preg_replace('/\D+/', '', trim($value)) ?? '';

        return '+' . ltrim($digits, '0');
    }

    private function normalizePhone(string $phone, string $countryCode): string
    {
        $phoneDigits = preg_replace('/\D+/', '', trim($phone)) ?? '';
        $countryDigits = ltrim(preg_replace('/\D+/', '', $countryCode) ?? '', '0');

        $phoneDigits = ltrim($phoneDigits, '0');

        if ($countryDigits !== '' && str_starts_with($phoneDigits, $countryDigits)) {
            return '+' . $phoneDigits;
        }

        return '+' . $countryDigits . $phoneDigits;
    }

    private function splitName(string $fullName): array
    {
        $segments = preg_split('/\s+/', trim($fullName)) ?: [];
        $firstName = $segments[0] ?? $fullName;
        $lastName = count($segments) > 1 ? implode(' ', array_slice($segments, 1)) : null;

        return [$firstName, $lastName];
    }
}
