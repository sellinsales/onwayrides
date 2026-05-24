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
use Illuminate\Validation\ValidationException;

class DriverModeController extends Controller
{
    use ResolvesFirebaseRequestUser;

    public function update(
        Request $request,
        FirebaseTokenVerifier $tokenVerifier,
        FirebaseUserSyncService $userSyncService
    ): JsonResponse {
        $payload = $request->validate([
            'is_online' => ['required', 'boolean'],
            'service_type_ids' => ['nullable', 'array'],
            'service_type_ids.*' => ['integer', Rule::exists('service_types', 'id')],
        ]);

        try {
            $user = $this->resolveAuthenticatedUser($request, $tokenVerifier, $userSyncService);
            $driverProfile = DB::table('driver_profiles')->where('user_id', $user->id)->first();

            if ($driverProfile === null) {
                throw ValidationException::withMessages([
                    'driver' => 'Start and submit a driver application before using driver mode.',
                ]);
            }

            $isApproved = $driverProfile->status === 'active'
                && $driverProfile->onboarding_status === 'approved';

            if (! $isApproved) {
                throw ValidationException::withMessages([
                    'driver' => 'Driver mode becomes available after approval.',
                ]);
            }

            $now = now();

            DB::table('driver_profiles')
                ->where('id', $driverProfile->id)
                ->update([
                    'is_online' => (bool) $payload['is_online'],
                    'updated_at' => $now,
                ]);

            if (isset($payload['service_type_ids'])) {
                $enabledIds = array_values(array_unique(array_map('intval', $payload['service_type_ids'])));

                DB::table('driver_service_enablements')
                    ->where('driver_profile_id', $driverProfile->id)
                    ->update([
                        'is_enabled' => 0,
                        'updated_at' => $now,
                    ]);

                if ($enabledIds !== []) {
                    DB::table('driver_service_enablements')
                        ->where('driver_profile_id', $driverProfile->id)
                        ->whereIn('service_type_id', $enabledIds)
                        ->update([
                            'is_enabled' => 1,
                            'updated_at' => $now,
                        ]);
                }
            }
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
            'message' => (bool) $payload['is_online']
                ? 'Driver mode is now online.'
                : 'Driver mode has been paused.',
        ]);
    }
}
