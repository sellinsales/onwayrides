<?php

namespace App\Services\Auth;

use App\Contracts\Auth\FirebaseTokenVerifier;
use App\Data\FirebaseIdentity;
use App\Exceptions\FirebaseAuthenticationException;
use App\Services\Firebase\FirebaseAdminProject;
use Kreait\Firebase\Auth;
use Kreait\Firebase\Exception\AuthException;
use Kreait\Firebase\Exception\FirebaseException;
use Kreait\Firebase\Exception\Auth\FailedToVerifyToken;

class KreaitFirebaseTokenVerifier implements FirebaseTokenVerifier
{
    private ?Auth $auth = null;

    public function __construct(
        private readonly FirebaseAdminProject $firebaseAdminProject
    ) {
    }

    public function verify(string $idToken): FirebaseIdentity
    {
        if (trim($idToken) === '') {
            throw new FirebaseAuthenticationException('Missing Firebase ID token.');
        }

        try {
            $verifiedToken = $this->auth()->verifyIdToken($idToken);
        } catch (FailedToVerifyToken|AuthException|FirebaseException $exception) {
            throw new FirebaseAuthenticationException('Invalid or expired Firebase ID token.', 0, $exception);
        }

        $claims = $verifiedToken->claims()->all();
        $uid = $this->firstStringClaim($claims, ['sub', 'user_id', 'uid']);

        if ($uid === null) {
            throw new FirebaseAuthenticationException('Firebase token does not contain a subject claim.');
        }

        return new FirebaseIdentity(
            uid: $uid,
            email: $this->firstStringClaim($claims, ['email']),
            phoneNumber: $this->firstStringClaim($claims, ['phone_number']),
            displayName: $this->firstStringClaim($claims, ['name']),
            photoUrl: $this->firstStringClaim($claims, ['picture']),
            emailVerified: (bool) ($claims['email_verified'] ?? false),
            claims: $claims,
        );
    }

    private function auth(): Auth
    {
        if ($this->auth !== null) {
            return $this->auth;
        }

        return $this->auth = $this->firebaseAdminProject->auth();
    }

    private function firstStringClaim(array $claims, array $keys): ?string
    {
        foreach ($keys as $key) {
            $value = $claims[$key] ?? null;

            if (is_string($value) && trim($value) !== '') {
                return trim($value);
            }
        }

        return null;
    }
}
