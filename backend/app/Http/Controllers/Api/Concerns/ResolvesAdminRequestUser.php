<?php

namespace App\Http\Controllers\Api\Concerns;

use App\Contracts\Auth\FirebaseTokenVerifier;
use App\Exceptions\FirebaseAuthenticationException;
use App\Exceptions\FirebaseConfigurationException;
use App\Models\User;
use App\Services\Auth\FirebaseUserSyncService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

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
