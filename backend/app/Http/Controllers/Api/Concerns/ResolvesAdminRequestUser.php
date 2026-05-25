<?php

namespace App\Http\Controllers\Api\Concerns;

use App\Contracts\Auth\FirebaseTokenVerifier;
use App\Exceptions\FirebaseAuthenticationException;
use App\Exceptions\FirebaseConfigurationException;
use App\Models\User;
use App\Services\Auth\FirebaseUserSyncService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

trait ResolvesAdminRequestUser
{
    /**
     * @return User|JsonResponse
     */
    protected function resolveAdminUser(
        Request $request,
        FirebaseTokenVerifier $tokenVerifier,
        FirebaseUserSyncService $userSyncService,
        array $allowedRoles = ['admin', 'support']
    ): User|JsonResponse {
        try {
            $identity = $tokenVerifier->verify($this->extractAdminIdToken($request));
            $user = $userSyncService->syncFromIdentity($identity, [
                'platform' => 'web-admin',
            ], false);
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

        if (! in_array($user->role, $allowedRoles, true)) {
            return response()->json([
                'status' => 'error',
                'message' => 'This account does not have access to the admin operations area.',
            ], 403);
        }

        return $user;
    }

    /**
     * @return User|JsonResponse
     */
    protected function resolveSuperAdminUser(
        Request $request,
        FirebaseTokenVerifier $tokenVerifier,
        FirebaseUserSyncService $userSyncService
    ): User|JsonResponse {
        $admin = $this->resolveAdminUser($request, $tokenVerifier, $userSyncService, ['admin']);

        if ($admin instanceof JsonResponse) {
            return $admin;
        }

        if (! $this->isSuperAdmin($admin)) {
            return response()->json([
                'status' => 'error',
                'message' => 'Only the primary platform admin can manage admin access.',
            ], 403);
        }

        return $admin;
    }

    protected function isSuperAdmin(User $user): bool
    {
        $configuredEmail = Str::lower(trim((string) config('onwayrides.super_admin_email', '')));
        $userEmail = Str::lower(trim((string) $user->email));

        return $configuredEmail !== ''
            && $userEmail === $configuredEmail
            && $user->role === 'admin';
    }

    /**
     * @throws FirebaseAuthenticationException
     */
    protected function extractAdminIdToken(Request $request): string
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
}
