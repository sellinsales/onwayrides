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

    private function authenticateRequest(
        Request $request,
        array $context,
        FirebaseTokenVerifier $tokenVerifier,
        FirebaseUserSyncService $userSyncService,
        bool $touchLogin
    ): JsonResponse {
        try {
            $identity = $tokenVerifier->verify($this->extractIdToken($request));
            $user = $userSyncService->syncFromIdentity($identity, $context, $touchLogin);
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
            'user' => $this->serializeUser($user),
        ]);
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
}
