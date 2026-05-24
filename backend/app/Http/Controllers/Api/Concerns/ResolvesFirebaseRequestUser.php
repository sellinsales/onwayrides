<?php

namespace App\Http\Controllers\Api\Concerns;

use App\Contracts\Auth\FirebaseTokenVerifier;
use App\Exceptions\FirebaseAuthenticationException;
use App\Exceptions\FirebaseConfigurationException;
use App\Models\User;
use App\Services\Auth\FirebaseUserSyncService;
use Illuminate\Http\Request;

trait ResolvesFirebaseRequestUser
{
    /**
     * @throws FirebaseAuthenticationException
     * @throws FirebaseConfigurationException
     */
    protected function resolveAuthenticatedUser(
        Request $request,
        FirebaseTokenVerifier $tokenVerifier,
        FirebaseUserSyncService $userSyncService,
        bool $touchLogin = false,
        array $context = []
    ): User {
        $identity = $tokenVerifier->verify($this->extractIdToken($request));

        return $userSyncService->syncFromIdentity($identity, $context, $touchLogin);
    }

    /**
     * @throws FirebaseAuthenticationException
     */
    protected function extractIdToken(Request $request): string
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
