<?php

namespace App\Services\Auth;

use App\Contracts\Auth\FirebaseTokenVerifier;
use App\Data\FirebaseIdentity;
use App\Exceptions\FirebaseAuthenticationException;
use App\Exceptions\FirebaseConfigurationException;
use Kreait\Firebase\Auth;
use Kreait\Firebase\Exception\AuthException;
use Kreait\Firebase\Exception\FirebaseException;
use Kreait\Firebase\Factory;
use Kreait\Firebase\Exception\Auth\FailedToVerifyToken;

class KreaitFirebaseTokenVerifier implements FirebaseTokenVerifier
{
    private ?Auth $auth = null;

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

        $credentials = $this->resolveCredentials();
        $projectId = trim((string) config('services.firebase.project_id', ''));

        $factory = new Factory();

        if ($projectId !== '') {
            $factory = $factory->withProjectId($projectId);
        }

        $factory = $factory->withServiceAccount($credentials);

        return $this->auth = $factory->createAuth();
    }

    private function resolveCredentials(): string|array
    {
        $credentialsPath = trim((string) config('services.firebase.credentials', ''));
        if ($credentialsPath !== '') {
            $resolvedPath = $this->resolvePath($credentialsPath);

            if (! is_file($resolvedPath)) {
                throw new FirebaseConfigurationException("Firebase credentials file not found at [{$resolvedPath}].");
            }

            return $resolvedPath;
        }

        $credentialsJson = trim((string) config('services.firebase.credentials_json', ''));
        if ($credentialsJson !== '') {
            $decodedCredentials = $this->decodeJsonCredentials($credentialsJson);

            if ($decodedCredentials !== null) {
                return $decodedCredentials;
            }

            throw new FirebaseConfigurationException('FIREBASE_CREDENTIALS_JSON is not valid JSON or base64-encoded JSON.');
        }

        throw new FirebaseConfigurationException(
            'Firebase credentials are not configured. Set FIREBASE_CREDENTIALS or FIREBASE_CREDENTIALS_JSON in the backend environment.'
        );
    }

    private function resolvePath(string $path): string
    {
        if (str_starts_with($path, DIRECTORY_SEPARATOR) || preg_match('/^[A-Za-z]:\\\\/', $path) === 1) {
            return $path;
        }

        return base_path($path);
    }

    private function decodeJsonCredentials(string $credentialsJson): ?array
    {
        $json = json_decode($credentialsJson, true);
        if (is_array($json)) {
            return $json;
        }

        $base64Decoded = base64_decode($credentialsJson, true);
        if ($base64Decoded === false) {
            return null;
        }

        $decodedJson = json_decode($base64Decoded, true);

        return is_array($decodedJson) ? $decodedJson : null;
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
