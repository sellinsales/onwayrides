<?php

namespace App\Http\Controllers\Api;

use App\Contracts\Auth\FirebaseTokenVerifier;
use App\Exceptions\FirebaseAuthenticationException;
use App\Exceptions\FirebaseConfigurationException;
use App\Http\Controllers\Api\Concerns\ResolvesFirebaseRequestUser;
use App\Http\Controllers\Controller;
use App\Services\Auth\FirebaseUserSyncService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class DeviceTokenController extends Controller
{
    use ResolvesFirebaseRequestUser;

    public function store(
        Request $request,
        FirebaseTokenVerifier $tokenVerifier,
        FirebaseUserSyncService $userSyncService
    ): JsonResponse {
        $payload = $request->validate([
            'token' => ['required', 'string', 'max:255'],
            'platform' => ['required', Rule::in(['android', 'ios', 'web'])],
            'device_name' => ['nullable', 'string', 'max:120'],
        ]);

        try {
            $user = $this->resolveAuthenticatedUser($request, $tokenVerifier, $userSyncService);
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

        $now = now();
        $token = trim((string) $payload['token']);

        $existingId = DB::table('device_tokens')
            ->where('token', $token)
            ->value('id');

        $record = [
            'user_id' => $user->id,
            'platform' => $payload['platform'],
            'device_name' => $payload['device_name'] ?? null,
            'token' => $token,
            'last_used_at' => $now,
            'updated_at' => $now,
        ];

        if ($existingId === null) {
            DB::table('device_tokens')->insert($record + [
                'created_at' => $now,
            ]);
        } else {
            DB::table('device_tokens')
                ->where('id', $existingId)
                ->update($record);
        }

        return response()->json([
            'status' => 'ok',
            'message' => 'Device token registered.',
        ]);
    }

    public function destroy(
        Request $request,
        FirebaseTokenVerifier $tokenVerifier,
        FirebaseUserSyncService $userSyncService
    ): JsonResponse {
        $payload = $request->validate([
            'token' => ['required', 'string', 'max:255'],
        ]);

        try {
            $user = $this->resolveAuthenticatedUser($request, $tokenVerifier, $userSyncService);
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

        DB::table('device_tokens')
            ->where('user_id', $user->id)
            ->where('token', trim((string) $payload['token']))
            ->delete();

        return response()->json([
            'status' => 'ok',
            'message' => 'Device token removed.',
        ]);
    }
}
