<?php

namespace App\Http\Controllers\Api;

use App\Contracts\Auth\FirebaseTokenVerifier;
use App\Exceptions\FirebaseAuthenticationException;
use App\Exceptions\FirebaseConfigurationException;
use App\Http\Controllers\Api\Concerns\ResolvesFirebaseRequestUser;
use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\Auth\FirebaseUserSyncService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class OnboardingController extends Controller
{
    use ResolvesFirebaseRequestUser;

    public function referenceData(Request $request): JsonResponse
    {
        $modelsByMake = DB::table('vehicle_models as vm')
            ->join('vehicle_makes as mk', 'mk.id', '=', 'vm.vehicle_make_id')
            ->where('vm.is_active', 1)
            ->where('mk.is_active', 1)
            ->orderBy('mk.name')
            ->orderBy('vm.name')
            ->get([
                'vm.id',
                'vm.vehicle_make_id',
                'vm.name',
            ]);

        return response()->json([
            'status' => 'ok',
            'cities' => DB::table('cities')
                ->where('is_enabled', 1)
                ->orderBy('name')
                ->get(['id', 'name', 'slug', 'province', 'country_code']),
            'service_types' => DB::table('service_types')
                ->where('is_active', 1)
                ->orderBy('sort_order')
                ->orderBy('name')
                ->get(['id', 'name', 'slug', 'category', 'supports_scheduling', 'supports_negotiation']),
            'vehicle_categories' => DB::table('vehicle_categories')
                ->orderBy('name')
                ->get(['id', 'name', 'slug', 'icon_name']),
            'vehicle_types' => DB::table('vehicle_types')
                ->where('is_active', 1)
                ->orderBy('name')
                ->get(['id', 'vehicle_category_id', 'name', 'slug', 'seats', 'luggage_capacity']),
            'vehicle_makes' => DB::table('vehicle_makes')
                ->where('is_active', 1)
                ->orderBy('name')
                ->get(['id', 'name']),
            'vehicle_models' => $modelsByMake,
            'driver_document_types' => [
                ['value' => 'profile_photo', 'label' => 'Selfie / profile photo'],
                ['value' => 'license', 'label' => 'Driver license'],
                ['value' => 'cnic', 'label' => 'National ID / CNIC'],
                ['value' => 'vehicle_registration', 'label' => 'Vehicle registration'],
                ['value' => 'route_permit', 'label' => 'Route permit'],
                ['value' => 'police_clearance', 'label' => 'Police clearance'],
                ['value' => 'other', 'label' => 'Other'],
            ],
            'driver_samples' => [
                'profile_photo' => 'Use a clear selfie in daylight, with your full face visible and no sunglasses.',
                'license' => 'Upload the front side of a valid, readable driver license.',
                'cnic' => 'Upload a clear national ID image with all corners visible.',
                'vehicle_registration' => 'Upload the latest registration card or document for the vehicle you plan to use.',
            ],
        ]);
    }

    public function workspace(
        Request $request,
        FirebaseTokenVerifier $tokenVerifier,
        FirebaseUserSyncService $userSyncService
    ): JsonResponse {
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

        return response()->json([
            'status' => 'ok',
            'workspace' => $this->buildWorkspacePayload($user),
        ]);
    }

    public function saveDriverDraft(
        Request $request,
        FirebaseTokenVerifier $tokenVerifier,
        FirebaseUserSyncService $userSyncService
    ): JsonResponse {
        $payload = $request->validate([
            'city_id' => ['required', 'integer', Rule::exists('cities', 'id')],
            'license_number' => ['required', 'string', 'max:100'],
            'national_id_number' => ['required', 'string', 'max:50'],
            'vehicle_category_id' => ['nullable', 'integer', Rule::exists('vehicle_categories', 'id')],
            'vehicle_type_id' => ['nullable', 'integer', Rule::exists('vehicle_types', 'id')],
            'vehicle_make_id' => ['nullable', 'integer', Rule::exists('vehicle_makes', 'id')],
            'vehicle_model_id' => ['nullable', 'integer', Rule::exists('vehicle_models', 'id')],
            'vehicle_make_other' => ['nullable', 'string', 'max:120'],
            'vehicle_model_other' => ['nullable', 'string', 'max:120'],
            'plate_number' => ['nullable', 'string', 'max:50'],
            'year_of_manufacture' => ['nullable', 'integer', 'between:1990,2100'],
            'seats' => ['nullable', 'integer', 'between:1,99'],
            'fuel_type' => ['nullable', Rule::in(['petrol', 'diesel', 'hybrid', 'electric', 'cng', 'other'])],
            'service_type_ids' => ['required', 'array', 'min:1'],
            'service_type_ids.*' => ['integer', Rule::exists('service_types', 'id')],
            'availability' => ['nullable', Rule::in(['full_time', 'part_time', 'weekends'])],
            'license_status' => ['nullable', Rule::in(['ready', 'renewing', 'need_help'])],
            'notes' => ['nullable', 'string', 'max:2000'],
        ]);

        try {
            $user = $this->resolveAuthenticatedUser($request, $tokenVerifier, $userSyncService);
            $workspace = DB::transaction(fn (): array => $this->persistDriverDraft($user, $payload));
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
        } catch (ValidationException $exception) {
            throw $exception;
        }

        return response()->json([
            'status' => 'ok',
            'message' => 'Driver onboarding draft saved.',
            'workspace' => $workspace,
        ]);
    }

    public function saveFleetDraft(
        Request $request,
        FirebaseTokenVerifier $tokenVerifier,
        FirebaseUserSyncService $userSyncService
    ): JsonResponse {
        $payload = $request->validate([
            'city_id' => ['required', 'integer', Rule::exists('cities', 'id')],
            'company_name' => ['required', 'string', 'max:191'],
            'fleet_size' => ['required', 'string', 'max:50'],
            'business_model' => ['required', Rule::in(['commission', 'subscription', 'hybrid'])],
            'use_case' => ['required', Rule::in(['fleet_owner', 'school_routes', 'staff_transport', 'airport_program'])],
            'support_phone' => ['nullable', 'string', 'max:30'],
            'support_email' => ['nullable', 'email', 'max:191'],
            'notes' => ['nullable', 'string', 'max:2000'],
        ]);

        try {
            $user = $this->resolveAuthenticatedUser($request, $tokenVerifier, $userSyncService);
            $workspace = DB::transaction(fn (): array => $this->persistFleetDraft($user, $payload));
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
            'message' => 'Fleet onboarding draft saved.',
            'workspace' => $workspace,
        ]);
    }

    /**
     * @return array<string, mixed>
     */
    private function persistDriverDraft(User $user, array $payload): array
    {
        $driverProfile = DB::table('driver_profiles')
            ->where('user_id', $user->id)
            ->first();

        $now = now();
        $driverProfileId = $driverProfile->id ?? null;

        if ($driverProfileId === null) {
            $driverProfileId = DB::table('driver_profiles')->insertGetId([
                'user_id' => $user->id,
                'driver_code' => $this->generateDriverCode(),
                'city_id' => $payload['city_id'],
                'license_number' => trim($payload['license_number']),
                'status' => 'pending',
                'onboarding_status' => 'documents_pending',
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }

        $vehicleId = null;
        $normalizedPlate = isset($payload['plate_number']) && trim((string) $payload['plate_number']) !== ''
            ? Str::upper(trim((string) $payload['plate_number']))
            : null;

        if ($normalizedPlate !== null) {
            $existingVehicle = DB::table('vehicles')
                ->where('plate_number', $normalizedPlate)
                ->first();

            if ($existingVehicle !== null && (int) $existingVehicle->registered_owner_user_id !== (int) $user->id) {
                throw ValidationException::withMessages([
                    'plate_number' => 'That plate number is already linked to another vehicle record.',
                ]);
            }
        }

        $metadata = is_array($user->metadata) ? $user->metadata : [];
        $driverMetadata = is_array($metadata['driver_onboarding'] ?? null) ? $metadata['driver_onboarding'] : [];
        $driverMetadata['availability'] = $payload['availability'] ?? null;
        $driverMetadata['license_status'] = $payload['license_status'] ?? null;
        $driverMetadata['vehicle_make_other'] = $payload['vehicle_make_other'] ?? null;
        $driverMetadata['vehicle_model_other'] = $payload['vehicle_model_other'] ?? null;
        $driverMetadata['service_type_ids'] = array_values(array_unique(array_map('intval', $payload['service_type_ids'])));
        $driverMetadata['draft_saved_at'] = $now->toIso8601String();
        $driverMetadata['submission_source'] = 'workspace-web';
        $metadata['driver_onboarding'] = $driverMetadata;
        $user->metadata = $metadata;
        $user->national_id_number = trim((string) $payload['national_id_number']);
        $user->save();

        DB::table('driver_profiles')
            ->where('id', $driverProfileId)
            ->update([
                'city_id' => $payload['city_id'],
                'license_number' => trim((string) $payload['license_number']),
                'status' => 'pending',
                'onboarding_status' => 'documents_pending',
                'business_model' => 'commission',
                'notes' => $payload['notes'] ?? null,
                'updated_at' => $now,
            ]);

        if ($payload['vehicle_type_id'] ?? null) {
            $existingVehicle = $normalizedPlate !== null
                ? DB::table('vehicles')->where('plate_number', $normalizedPlate)->first()
                : null;

            if ($existingVehicle !== null) {
                $vehicleId = (int) $existingVehicle->id;
                DB::table('vehicles')
                    ->where('id', $vehicleId)
                    ->update([
                        'vehicle_type_id' => $payload['vehicle_type_id'],
                        'vehicle_make_id' => $payload['vehicle_make_id'] ?? null,
                        'vehicle_model_id' => $payload['vehicle_model_id'] ?? null,
                        'plate_number' => $normalizedPlate,
                        'year_of_manufacture' => $payload['year_of_manufacture'] ?? null,
                        'seats' => $payload['seats'] ?? null,
                        'fuel_type' => $payload['fuel_type'] ?? 'petrol',
                        'status' => 'pending',
                        'registered_owner_user_id' => $user->id,
                        'metadata' => json_encode([
                            'vehicle_make_other' => $payload['vehicle_make_other'] ?? null,
                            'vehicle_model_other' => $payload['vehicle_model_other'] ?? null,
                            'driver_profile_id' => $driverProfileId,
                        ], JSON_THROW_ON_ERROR),
                        'updated_at' => $now,
                    ]);
            } else {
                $vehicleId = DB::table('vehicles')->insertGetId([
                    'registered_owner_user_id' => $user->id,
                    'vehicle_type_id' => $payload['vehicle_type_id'],
                    'vehicle_make_id' => $payload['vehicle_make_id'] ?? null,
                    'vehicle_model_id' => $payload['vehicle_model_id'] ?? null,
                    'plate_number' => $normalizedPlate ?? $this->generateTemporaryPlate($driverProfileId),
                    'year_of_manufacture' => $payload['year_of_manufacture'] ?? null,
                    'seats' => $payload['seats'] ?? null,
                    'fuel_type' => $payload['fuel_type'] ?? 'petrol',
                    'status' => 'pending',
                    'metadata' => json_encode([
                        'vehicle_make_other' => $payload['vehicle_make_other'] ?? null,
                        'vehicle_model_other' => $payload['vehicle_model_other'] ?? null,
                        'driver_profile_id' => $driverProfileId,
                    ], JSON_THROW_ON_ERROR),
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }
        }

        DB::table('driver_service_enablements')
            ->where('driver_profile_id', $driverProfileId)
            ->delete();

        foreach (array_values(array_unique(array_map('intval', $payload['service_type_ids']))) as $serviceTypeId) {
            DB::table('driver_service_enablements')->insert([
                'driver_profile_id' => $driverProfileId,
                'service_type_id' => $serviceTypeId,
                'is_enabled' => 1,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }

        return $this->buildWorkspacePayload($user->fresh(), $driverProfileId, $vehicleId);
    }

    /**
     * @return array<string, mixed>
     */
    private function persistFleetDraft(User $user, array $payload): array
    {
        $fleetOwner = DB::table('fleet_owners')
            ->where('user_id', $user->id)
            ->first();

        $now = now();
        $fleetOwnerId = $fleetOwner->id ?? null;
        $fleetCode = $fleetOwner->fleet_code ?? $this->generateFleetCode();

        if ($fleetOwnerId === null) {
            $fleetOwnerId = DB::table('fleet_owners')->insertGetId([
                'user_id' => $user->id,
                'city_id' => $payload['city_id'],
                'fleet_code' => $fleetCode,
                'company_name' => trim((string) $payload['company_name']),
                'business_model' => $payload['business_model'],
                'status' => 'pending',
                'support_email' => $payload['support_email'] ?? $user->email,
                'support_phone' => $payload['support_phone'] ?? $user->phone,
                'notes' => $payload['notes'] ?? null,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        } else {
            DB::table('fleet_owners')
                ->where('id', $fleetOwnerId)
                ->update([
                    'city_id' => $payload['city_id'],
                    'company_name' => trim((string) $payload['company_name']),
                    'business_model' => $payload['business_model'],
                    'status' => 'pending',
                    'support_email' => $payload['support_email'] ?? $user->email,
                    'support_phone' => $payload['support_phone'] ?? $user->phone,
                    'notes' => $payload['notes'] ?? null,
                    'updated_at' => $now,
                ]);
        }

        $metadata = is_array($user->metadata) ? $user->metadata : [];
        $fleetMetadata = is_array($metadata['fleet_onboarding'] ?? null) ? $metadata['fleet_onboarding'] : [];
        $fleetMetadata['fleet_size'] = trim((string) $payload['fleet_size']);
        $fleetMetadata['use_case'] = $payload['use_case'];
        $fleetMetadata['draft_saved_at'] = $now->toIso8601String();
        $metadata['fleet_onboarding'] = $fleetMetadata;
        $user->metadata = $metadata;
        $user->save();

        return $this->buildWorkspacePayload($user->fresh(), null, null, $fleetOwnerId);
    }

    /**
     * @return array<string, mixed>
     */
    private function buildWorkspacePayload(
        User $user,
        ?int $driverProfileId = null,
        ?int $vehicleId = null,
        ?int $fleetOwnerId = null
    ): array {
        $driverProfile = $driverProfileId !== null
            ? DB::table('driver_profiles')->where('id', $driverProfileId)->first()
            : DB::table('driver_profiles')->where('user_id', $user->id)->first();

        $fleetOwner = $fleetOwnerId !== null
            ? DB::table('fleet_owners')->where('id', $fleetOwnerId)->first()
            : DB::table('fleet_owners')->where('user_id', $user->id)->first();

        $primaryVehicle = null;
        if ($vehicleId !== null) {
            $primaryVehicle = DB::table('vehicles')->where('id', $vehicleId)->first();
        } elseif ($driverProfile !== null) {
            $driverVehicleAssignment = DB::table('driver_vehicle_assignments')
                ->where('driver_profile_id', $driverProfile->id)
                ->where('is_current', 1)
                ->first();

            if ($driverVehicleAssignment !== null) {
                $primaryVehicle = DB::table('vehicles')->where('id', $driverVehicleAssignment->vehicle_id)->first();
            }
        }

        $driverDocuments = [];
        if ($driverProfile !== null) {
            $driverDocuments = DB::table('driver_documents')
                ->where('driver_profile_id', $driverProfile->id)
                ->orderByDesc('updated_at')
                ->get(['id', 'document_type', 'status', 'expiry_date', 'updated_at'])
                ->map(fn ($document): array => [
                    'id' => $document->id,
                    'document_type' => $document->document_type,
                    'status' => $document->status,
                    'expiry_date' => $document->expiry_date,
                    'updated_at' => $document->updated_at,
                ])
                ->all();
        }

        return [
            'user' => [
                'id' => $user->id,
                'full_name' => $user->full_name,
                'email' => $user->email,
                'phone' => $user->phone,
                'country_code' => $user->country_code,
                'national_id_number' => $user->national_id_number,
                'role' => $user->role,
            ],
            'driver_application' => $driverProfile === null ? null : [
                'driver_profile_id' => $driverProfile->id,
                'driver_code' => $driverProfile->driver_code,
                'status' => $driverProfile->status,
                'onboarding_status' => $driverProfile->onboarding_status,
                'city_id' => $driverProfile->city_id,
                'is_online' => (bool) $driverProfile->is_online,
                'is_busy' => (bool) $driverProfile->is_busy,
                'accepts_cash' => (bool) $driverProfile->accepts_cash,
                'accepts_wallet' => (bool) $driverProfile->accepts_wallet,
                'accepts_card' => (bool) $driverProfile->accepts_card,
                'rating_average' => (float) $driverProfile->rating_average,
                'rating_count' => (int) $driverProfile->rating_count,
                'trips_completed' => (int) $driverProfile->trips_completed,
                'license_number' => $driverProfile->license_number,
                'notes' => $driverProfile->notes,
                'documents' => $driverDocuments,
                'vehicle' => $primaryVehicle === null ? null : [
                    'id' => $primaryVehicle->id,
                    'plate_number' => $primaryVehicle->plate_number,
                    'vehicle_category_id' => DB::table('vehicle_types')
                        ->where('id', $primaryVehicle->vehicle_type_id)
                        ->value('vehicle_category_id'),
                    'vehicle_type_id' => $primaryVehicle->vehicle_type_id,
                    'vehicle_make_id' => $primaryVehicle->vehicle_make_id,
                    'vehicle_model_id' => $primaryVehicle->vehicle_model_id,
                    'year_of_manufacture' => $primaryVehicle->year_of_manufacture,
                    'seats' => $primaryVehicle->seats,
                    'fuel_type' => $primaryVehicle->fuel_type,
                    'status' => $primaryVehicle->status,
                ],
                'service_type_ids' => DB::table('driver_service_enablements')
                    ->where('driver_profile_id', $driverProfile->id)
                    ->orderBy('service_type_id')
                    ->pluck('service_type_id')
                    ->map(fn ($id): int => (int) $id)
                    ->all(),
            ],
            'fleet_application' => $fleetOwner === null ? null : [
                'fleet_owner_id' => $fleetOwner->id,
                'fleet_code' => $fleetOwner->fleet_code,
                'company_name' => $fleetOwner->company_name,
                'city_id' => $fleetOwner->city_id,
                'business_model' => $fleetOwner->business_model,
                'status' => $fleetOwner->status,
                'support_email' => $fleetOwner->support_email,
                'support_phone' => $fleetOwner->support_phone,
                'notes' => $fleetOwner->notes,
            ],
            'metadata' => $user->metadata ?? [],
        ];
    }

    private function generateDriverCode(): string
    {
        do {
            $code = 'DRV-' . Str::upper(Str::random(8));
        } while (DB::table('driver_profiles')->where('driver_code', $code)->exists());

        return $code;
    }

    private function generateFleetCode(): string
    {
        do {
            $code = 'FLT-' . Str::upper(Str::random(8));
        } while (DB::table('fleet_owners')->where('fleet_code', $code)->exists());

        return $code;
    }

    private function generateTemporaryPlate(int $driverProfileId): string
    {
        return 'ONWAY-' . $driverProfileId . '-' . Str::upper(Str::random(4));
    }
}
