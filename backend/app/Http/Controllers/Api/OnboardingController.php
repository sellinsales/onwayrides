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

    private const DRIVER_DOCUMENT_TYPES = [
        'profile_photo' => [
            'label' => 'Selfie / profile photo',
            'sample_hint' => 'Use a clear selfie in daylight, with your full face visible and no sunglasses.',
            'sort_order' => 10,
            'required' => true,
        ],
        'license' => [
            'label' => 'Driver license',
            'sample_hint' => 'Upload the front side of a valid, readable driver license.',
            'sort_order' => 20,
            'required' => true,
        ],
        'cnic' => [
            'label' => 'National ID / CNIC',
            'sample_hint' => 'Upload a clear national ID image with all corners visible.',
            'sort_order' => 30,
            'required' => true,
        ],
        'vehicle_registration' => [
            'label' => 'Vehicle registration',
            'sample_hint' => 'Upload the latest registration card or document for the vehicle you plan to use.',
            'sort_order' => 40,
            'required_when_vehicle' => true,
        ],
        'route_permit' => [
            'label' => 'Route permit',
            'sample_hint' => 'Upload this only if your city or service type requires a route permit.',
            'sort_order' => 50,
        ],
        'police_clearance' => [
            'label' => 'Police clearance',
            'sample_hint' => 'Upload this if requested during compliance review.',
            'sort_order' => 60,
        ],
        'other' => [
            'label' => 'Other',
            'sample_hint' => 'Use this only when support asks for an extra document.',
            'sort_order' => 70,
        ],
    ];

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
            'driver_document_types' => $this->driverDocumentTypeDefinitions(false),
            'driver_samples' => collect($this->driverDocumentTypeDefinitions(false))
                ->filter(fn (array $definition): bool => ! empty($definition['sample_hint']))
                ->mapWithKeys(fn (array $definition): array => [
                    $definition['value'] => $definition['sample_hint'],
                ])
                ->all(),
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

    public function activateDriverDemoAccess(
        Request $request,
        FirebaseTokenVerifier $tokenVerifier,
        FirebaseUserSyncService $userSyncService
    ): JsonResponse {
        if (! config('onwayrides.beta.driver_demo_access_enabled', false)) {
            return response()->json([
                'status' => 'error',
                'message' => 'Demo driver access is unavailable right now.',
            ], 403);
        }

        try {
            $user = $this->resolveAuthenticatedUser($request, $tokenVerifier, $userSyncService);
            $workspace = DB::transaction(fn (): array => $this->grantDriverDemoAccess($user));
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
            'message' => 'Temporary demo driver access is now active.',
            'workspace' => $workspace,
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

        $existingOnboardingStatus = (string) ($driverProfile->onboarding_status ?? '');
        $existingDriverStatus = (string) ($driverProfile->status ?? '');
        $demoAccessEnabled = $this->userHasDriverDemoAccess($user);
        $hasExistingDocuments = DB::table('driver_documents')
            ->where('driver_profile_id', $driverProfileId)
            ->exists();

        $nextOnboardingStatus = in_array($existingOnboardingStatus, ['approved', 'rejected'], true)
            ? $existingOnboardingStatus
            : ($hasExistingDocuments ? 'review' : 'documents_pending');
        $nextDriverStatus = ($demoAccessEnabled
                || ($existingDriverStatus === 'active' && $existingOnboardingStatus === 'approved'))
            ? 'active'
            : 'pending';

        DB::table('driver_profiles')
            ->where('id', $driverProfileId)
            ->update([
                'city_id' => $payload['city_id'],
                'license_number' => trim((string) $payload['license_number']),
                'status' => $nextDriverStatus,
                'onboarding_status' => $nextOnboardingStatus,
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
                $vehicleStatus = ((string) ($existingVehicle->status ?? '') === 'active' || $demoAccessEnabled)
                    ? 'active'
                    : 'pending';
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
                        'status' => $vehicleStatus,
                        'registered_owner_user_id' => $user->id,
                        'metadata' => json_encode([
                            'vehicle_make_other' => $payload['vehicle_make_other'] ?? null,
                            'vehicle_model_other' => $payload['vehicle_model_other'] ?? null,
                            'driver_profile_id' => $driverProfileId,
                        ], JSON_THROW_ON_ERROR),
                        'updated_at' => $now,
                    ]);
            } else {
                $vehicleStatus = $demoAccessEnabled ? 'active' : 'pending';
                $vehicleId = DB::table('vehicles')->insertGetId([
                    'registered_owner_user_id' => $user->id,
                    'vehicle_type_id' => $payload['vehicle_type_id'],
                    'vehicle_make_id' => $payload['vehicle_make_id'] ?? null,
                    'vehicle_model_id' => $payload['vehicle_model_id'] ?? null,
                    'plate_number' => $normalizedPlate ?? $this->generateTemporaryPlate($driverProfileId),
                    'year_of_manufacture' => $payload['year_of_manufacture'] ?? null,
                    'seats' => $payload['seats'] ?? null,
                    'fuel_type' => $payload['fuel_type'] ?? 'petrol',
                    'status' => $vehicleStatus,
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
            $documentDefinitions = collect(
                $this->driverDocumentTypeDefinitions($primaryVehicle !== null)
            )->keyBy('value');

            $driverDocuments = DB::table('driver_documents')
                ->where('driver_profile_id', $driverProfile->id)
                ->orderByDesc('updated_at')
                ->get([
                    'id',
                    'document_type',
                    'status',
                    'expiry_date',
                    'created_at',
                    'reviewed_at',
                    'rejection_reason',
                    'updated_at',
                ])
                ->map(function ($document) use ($documentDefinitions): array {
                    $definition = $documentDefinitions->get((string) $document->document_type, []);

                    return [
                        'id' => (int) $document->id,
                        'document_type' => (string) $document->document_type,
                        'document_label' => (string) ($definition['label']
                            ?? Str::headline(str_replace('_', ' ', (string) $document->document_type))),
                        'status' => (string) $document->status,
                        'status_label' => Str::headline(str_replace('_', ' ', (string) $document->status)),
                        'expiry_date' => $document->expiry_date,
                        'submitted_at' => $document->created_at,
                        'reviewed_at' => $document->reviewed_at,
                        'rejection_reason' => $document->rejection_reason,
                        'updated_at' => $document->updated_at,
                        'is_required' => (bool) ($definition['is_required'] ?? false),
                        'can_resubmit' => in_array((string) $document->status, ['rejected', 'expired'], true),
                        'sample_hint' => $definition['sample_hint'] ?? null,
                        'sort_order' => (int) ($definition['sort_order'] ?? 999),
                    ];
                })
                ->sortBy('sort_order')
                ->values()
                ->all();
        }

        $driverChecklist = $driverProfile === null
            ? null
            : $this->buildDriverChecklist(
                $user,
                $driverProfile,
                $primaryVehicle,
                $driverDocuments
            );

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
                'checklist' => $driverChecklist,
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
            'demo_driver_access' => [
                'enabled' => $this->userHasDriverDemoAccess($user),
                'can_activate' => (bool) config('onwayrides.beta.driver_demo_access_enabled', false),
            ],
            'metadata' => $user->metadata ?? [],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function grantDriverDemoAccess(User $user): array
    {
        $now = now();
        $metadata = is_array($user->metadata) ? $user->metadata : [];
        $metadata['driver_demo_access'] = [
            'enabled' => true,
            'temporary' => true,
            'activated_at' => $now->toIso8601String(),
        ];
        $user->metadata = $metadata;
        $user->save();

        $driverProfile = DB::table('driver_profiles')
            ->where('user_id', $user->id)
            ->first();

        $cityId = (int) ($driverProfile->city_id
            ?? DB::table('cities')->where('is_enabled', 1)->orderBy('id')->value('id')
            ?? 1);
        $licenseNumber = trim((string) ($driverProfile->license_number ?? 'LIC-DEMO-' . $user->id));
        $driverCode = trim((string) ($driverProfile->driver_code ?? $this->generateDriverCode()));

        if ($driverProfile === null) {
            $driverProfileId = DB::table('driver_profiles')->insertGetId([
                'user_id' => $user->id,
                'city_id' => $cityId,
                'driver_code' => $driverCode,
                'license_number' => $licenseNumber,
                'business_model' => 'commission',
                'status' => 'active',
                'onboarding_status' => 'approved',
                'is_online' => 0,
                'is_busy' => 0,
                'accepts_cash' => 1,
                'accepts_wallet' => 0,
                'accepts_card' => 0,
                'notes' => 'Temporary demo driver access enabled for this user.',
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        } else {
            $driverProfileId = (int) $driverProfile->id;
            DB::table('driver_profiles')
                ->where('id', $driverProfileId)
                ->update([
                    'city_id' => $cityId,
                    'driver_code' => $driverCode,
                    'license_number' => $licenseNumber,
                    'business_model' => $driverProfile->business_model ?? 'commission',
                    'status' => 'active',
                    'onboarding_status' => 'approved',
                    'is_busy' => 0,
                    'updated_at' => $now,
                ]);
        }

        $vehicleId = $this->ensureDemoVehicleForDriver($user, $driverProfileId);
        $this->assignDemoVehicleToDriver($driverProfileId, $vehicleId, $user->id);
        $this->enableDemoDriverServices($driverProfileId, $user->id);

        return $this->buildWorkspacePayload($user->fresh(), $driverProfileId, $vehicleId);
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

    private function ensureDemoVehicleForDriver(User $user, int $driverProfileId): int
    {
        $now = now();
        $existingVehicleId = DB::table('driver_vehicle_assignments')
            ->where('driver_profile_id', $driverProfileId)
            ->where('is_current', 1)
            ->value('vehicle_id');

        if ($existingVehicleId !== null) {
            DB::table('vehicles')
                ->where('id', $existingVehicleId)
                ->update([
                    'status' => 'active',
                    'registered_owner_user_id' => $user->id,
                    'updated_at' => $now,
                ]);

            return (int) $existingVehicleId;
        }

        $ownerVehicle = DB::table('vehicles')
            ->where('registered_owner_user_id', $user->id)
            ->orderByDesc('updated_at')
            ->first();

        $vehicleTypeId = (int) (DB::table('vehicle_types')
            ->where('is_active', 1)
            ->orderBy('id')
            ->value('id') ?? 1);
        $vehicleMakeId = DB::table('vehicle_makes')
            ->where('is_active', 1)
            ->orderBy('id')
            ->value('id');
        $vehicleModelId = $vehicleMakeId !== null
            ? DB::table('vehicle_models')
                ->where('vehicle_make_id', $vehicleMakeId)
                ->where('is_active', 1)
                ->orderBy('id')
                ->value('id')
            : null;

        if ($ownerVehicle !== null) {
            DB::table('vehicles')
                ->where('id', $ownerVehicle->id)
                ->update([
                    'vehicle_type_id' => $ownerVehicle->vehicle_type_id ?? $vehicleTypeId,
                    'vehicle_make_id' => $ownerVehicle->vehicle_make_id ?? $vehicleMakeId,
                    'vehicle_model_id' => $ownerVehicle->vehicle_model_id ?? $vehicleModelId,
                    'status' => 'active',
                    'registered_owner_user_id' => $user->id,
                    'updated_at' => $now,
                ]);

            return (int) $ownerVehicle->id;
        }

        return (int) DB::table('vehicles')->insertGetId([
            'registered_owner_user_id' => $user->id,
            'vehicle_type_id' => $vehicleTypeId,
            'vehicle_make_id' => $vehicleMakeId,
            'vehicle_model_id' => $vehicleModelId,
            'plate_number' => $this->generateTemporaryPlate($driverProfileId),
            'color' => 'White',
            'year_of_manufacture' => (int) now()->format('Y'),
            'seats' => 4,
            'fuel_type' => 'petrol',
            'status' => 'active',
            'metadata' => json_encode([
                'demo_vehicle' => true,
                'driver_profile_id' => $driverProfileId,
            ], JSON_THROW_ON_ERROR),
            'created_at' => $now,
            'updated_at' => $now,
        ]);
    }

    private function assignDemoVehicleToDriver(int $driverProfileId, int $vehicleId, int $userId): void
    {
        $now = now();

        DB::table('driver_vehicle_assignments')
            ->where('driver_profile_id', $driverProfileId)
            ->where('is_current', 1)
            ->update([
                'is_current' => 0,
                'ends_at' => $now,
                'updated_at' => $now,
            ]);

        $existingAssignment = DB::table('driver_vehicle_assignments')
            ->where('driver_profile_id', $driverProfileId)
            ->where('vehicle_id', $vehicleId)
            ->whereNull('ends_at')
            ->latest('id')
            ->first();

        if ($existingAssignment !== null) {
            DB::table('driver_vehicle_assignments')
                ->where('id', $existingAssignment->id)
                ->update([
                    'assigned_by_user_id' => $userId,
                    'starts_at' => $existingAssignment->starts_at ?? $now,
                    'ends_at' => null,
                    'is_current' => 1,
                    'notes' => 'Temporary demo driver vehicle assignment.',
                    'updated_at' => $now,
                ]);

            return;
        }

        DB::table('driver_vehicle_assignments')->insert([
            'driver_profile_id' => $driverProfileId,
            'vehicle_id' => $vehicleId,
            'assigned_by_user_id' => $userId,
            'starts_at' => $now,
            'ends_at' => null,
            'is_current' => 1,
            'notes' => 'Temporary demo driver vehicle assignment.',
            'created_at' => $now,
            'updated_at' => $now,
        ]);
    }

    private function enableDemoDriverServices(int $driverProfileId, int $userId): void
    {
        $now = now();
        $serviceTypeIds = DB::table('service_types')
            ->where('is_active', 1)
            ->where('supports_driver_mode', 1)
            ->orderBy('sort_order')
            ->orderBy('id')
            ->pluck('id')
            ->map(fn ($id): int => (int) $id)
            ->all();

        DB::table('driver_service_enablements')
            ->where('driver_profile_id', $driverProfileId)
            ->update([
                'is_enabled' => 0,
                'updated_at' => $now,
            ]);

        foreach ($serviceTypeIds as $serviceTypeId) {
            $existing = DB::table('driver_service_enablements')
                ->where('driver_profile_id', $driverProfileId)
                ->where('service_type_id', $serviceTypeId)
                ->first();

            if ($existing !== null) {
                DB::table('driver_service_enablements')
                    ->where('id', $existing->id)
                    ->update([
                        'is_enabled' => 1,
                        'approved_by_user_id' => $userId,
                        'updated_at' => $now,
                    ]);

                continue;
            }

            DB::table('driver_service_enablements')->insert([
                'driver_profile_id' => $driverProfileId,
                'service_type_id' => $serviceTypeId,
                'is_enabled' => 1,
                'approved_by_user_id' => $userId,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }
    }

    private function userHasDriverDemoAccess(User $user): bool
    {
        $metadata = is_array($user->metadata) ? $user->metadata : [];

        return (bool) ($metadata['driver_demo_access']['enabled'] ?? false);
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function driverDocumentTypeDefinitions(bool $vehicleAssigned): array
    {
        return collect(self::DRIVER_DOCUMENT_TYPES)
            ->map(function (array $definition, string $value) use ($vehicleAssigned): array {
                $isRequired = (bool) ($definition['required'] ?? false);
                if (! $isRequired && ($definition['required_when_vehicle'] ?? false)) {
                    $isRequired = $vehicleAssigned;
                }

                return [
                    'value' => $value,
                    'label' => $definition['label'],
                    'sample_hint' => $definition['sample_hint'] ?? null,
                    'sort_order' => (int) ($definition['sort_order'] ?? 999),
                    'is_required' => $isRequired,
                ];
            })
            ->sortBy('sort_order')
            ->values()
            ->all();
    }

    /**
     * @param array<int, array<string, mixed>> $driverDocuments
     * @return array<string, mixed>
     */
    private function buildDriverChecklist(
        User $user,
        object $driverProfile,
        ?object $primaryVehicle,
        array $driverDocuments
    ): array {
        $serviceTypeIds = DB::table('driver_service_enablements')
            ->where('driver_profile_id', $driverProfile->id)
            ->pluck('service_type_id')
            ->map(fn ($id): int => (int) $id)
            ->all();

        $documentDefinitions = collect(
            $this->driverDocumentTypeDefinitions($primaryVehicle !== null)
        );
        $requiredDocumentTypes = $documentDefinitions
            ->filter(fn (array $definition): bool => (bool) $definition['is_required'])
            ->pluck('value')
            ->all();

        $documentsByType = collect($driverDocuments)->keyBy('document_type');
        $submittedRequired = collect($requiredDocumentTypes)
            ->filter(fn (string $type): bool => $documentsByType->has($type))
            ->values();
        $approvedRequired = $submittedRequired
            ->filter(fn (string $type): bool => ($documentsByType->get($type)['status'] ?? null) === 'approved')
            ->values();
        $rejectedRequired = $submittedRequired
            ->filter(fn (string $type): bool => in_array(
                (string) ($documentsByType->get($type)['status'] ?? ''),
                ['rejected', 'expired'],
                true
            ))
            ->values();

        $profileComplete = (int) ($driverProfile->city_id ?? 0) > 0
            && trim((string) ($driverProfile->license_number ?? '')) !== ''
            && trim((string) ($user->national_id_number ?? '')) !== ''
            && $serviceTypeIds !== [];
        $vehicleComplete = $primaryVehicle !== null
            && (int) ($primaryVehicle->vehicle_type_id ?? 0) > 0
            && trim((string) ($primaryVehicle->plate_number ?? '')) !== '';
        $requiredTotal = count($requiredDocumentTypes);
        $submittedCount = $submittedRequired->count();
        $approvedCount = $approvedRequired->count();
        $rejectedCount = $rejectedRequired->count();
        $allRequiredSubmitted = $requiredTotal > 0 && $submittedCount >= $requiredTotal;
        $allRequiredApproved = $requiredTotal > 0 && $approvedCount >= $requiredTotal;
        $activationReady = $driverProfile->status === 'active' && $driverProfile->onboarding_status === 'approved';

        $stage = 'profile';
        $nextAction = 'Complete your driver profile.';

        if ($activationReady) {
            $stage = 'approved';
            $nextAction = 'Go online and start receiving ride requests.';
        } elseif (! $profileComplete) {
            $stage = 'profile';
            $nextAction = 'Complete your profile, service choices, and identity details.';
        } elseif (! $vehicleComplete) {
            $stage = 'vehicle';
            $nextAction = 'Add your main vehicle details to continue.';
        } elseif ($rejectedCount > 0) {
            $stage = 'documents';
            $nextAction = 'Replace the rejected documents and resubmit them for review.';
        } elseif (! $allRequiredSubmitted) {
            $stage = 'documents';
            $nextAction = 'Upload every required document to submit your application.';
        } elseif (! $allRequiredApproved) {
            $stage = 'review';
            $nextAction = 'Your required documents are submitted. Wait for review or replace any document if requested.';
        } else {
            $stage = 'activation';
            $nextAction = 'Everything required is approved. Final account activation is the next step.';
        }

        return [
            'stage' => $stage,
            'next_action' => $nextAction,
            'profile_complete' => $profileComplete,
            'vehicle_complete' => $vehicleComplete,
            'all_required_submitted' => $allRequiredSubmitted,
            'all_required_approved' => $allRequiredApproved,
            'activation_ready' => $activationReady,
            'review_pending' => $allRequiredSubmitted && ! $allRequiredApproved,
            'required_document_types' => $requiredDocumentTypes,
            'required_documents_total' => $requiredTotal,
            'required_documents_submitted' => $submittedCount,
            'required_documents_approved' => $approvedCount,
            'required_documents_rejected' => $rejectedCount,
        ];
    }
}
