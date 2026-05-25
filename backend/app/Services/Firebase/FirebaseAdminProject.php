<?php

namespace App\Services\Firebase;

use App\Exceptions\FirebaseConfigurationException;
use Kreait\Firebase\Auth;
use Kreait\Firebase\Contract\Messaging;
use Kreait\Firebase\Factory;

class FirebaseAdminProject
{
    private ?Auth $auth = null;

    private ?Messaging $messaging = null;

    public function auth(): Auth
    {
        if ($this->auth !== null) {
            return $this->auth;
        }

        return $this->auth = $this->factory()->createAuth();
    }

    public function messaging(): Messaging
    {
        if ($this->messaging !== null) {
            return $this->messaging;
        }

        return $this->messaging = $this->factory()->createMessaging();
    }

    private function factory(): Factory
    {
        $credentials = $this->resolveCredentials();
        $projectId = trim((string) config('services.firebase.project_id', ''));

        $factory = new Factory();

        if ($projectId !== '') {
            $factory = $factory->withProjectId($projectId);
        }

        return $factory->withServiceAccount($credentials);
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
}
