<?php

namespace App\Http\Controllers\Api;

use App\Contracts\Auth\FirebaseTokenVerifier;
use App\Http\Controllers\Api\Concerns\ResolvesAdminRequestUser;
use App\Http\Controllers\Controller;
use App\Services\Auth\FirebaseUserSyncService;
use App\Services\PushNotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class AdminDriverApprovalController extends Controller
{
    use ResolvesAdminRequestUser;

    private const REQUIRED_DOCUMENT_TYPES = [
        'profile_photo',
        'license',
        'cnic',
    ];

    public function index(
        Request $request,
        FirebaseTokenVerifier $tokenVerifier,
        FirebaseUserSyncService $userSyncService
    ): JsonResponse {
        $admin = $this->resolveAdminUser($request, $tokenVerifier, $userSyncService);
        if ($admin instanceof JsonResponse) {
            return $admin;
        }

        $filters = $request->validate([
            'q' => ['nullable', 'string', 'max:191'],
            'state' => ['nullable', Rule::in(['all', 'pending', 'review', 'approved', 'rejected', 'suspended'])],
            'city_id' => ['nullable', 'integer', Rule::exists('cities', 'id')],
        ]);

        $profiles = $this->driverApplicationsQuery($filters)
            ->orderByRaw("FIELD(dp.onboarding_status, 'documents_pending', 'review', 'approved', 'rejected')")
            ->orderByDesc('dp.updated_at')
            ->limit(200)
            ->get();

        return response()->json([
            'status' => 'ok',
            'viewer' => [
                'id' => $admin->id,
                'email' => $admin->email,
                'role' => $admin->role,
                'can_manage_admins' => $this->isSuperAdmin($admin),
            ],
            'filters' => [
                'q' => $filters['q'] ?? null,
                'state' => $filters['state'] ?? 'pending',
                'city_id' => isset($filters['city_id']) ? (int) $filters['city_id'] : null,
            ],
            'role_management' => [
                'enabled' => $this->isSuperAdmin($admin),
                'primary_admin_email' => config('onwayrides.super_admin_email'),
                'users_endpoint' => route('api.admin.users.index', absolute: false),
            ],
            'dispatch' => [
                'endpoint' => route('api.admin.bookings.dispatch.index', absolute: false),
            ],
            'summary' => $this->buildSummary(),
            'data' => $profiles->map(fn (object $profile): array => $this->serializeListItem($profile))->all(),
        ]);
    }

    public function show(
        Request $request,
        int $driverProfileId,
        FirebaseTokenVerifier $tokenVerifier,
        FirebaseUserSyncService $userSyncService
    ): JsonResponse {
        $admin = $this->resolveAdminUser($request, $tokenVerifier, $userSyncService);
        if ($admin instanceof JsonResponse) {
            return $admin;
        }

        $profile = $this->baseProfileQuery()
            ->where('dp.id', $driverProfileId)
            ->first();

        if ($profile === null) {
            return response()->json([
                'status' => 'error',
                'message' => 'Driver application not found.',
            ], 404);
        }

        return response()->json([
            'status' => 'ok',
            'application' => $this->serializeDetail($profile),
        ]);
    }

    public function updateDocumentStatus(
        Request $request,
        int $documentId,
        FirebaseTokenVerifier $tokenVerifier,
        FirebaseUserSyncService $userSyncService,
        PushNotificationService $pushNotificationService
    ): JsonResponse {
        $admin = $this->resolveAdminUser($request, $tokenVerifier, $userSyncService);
        if ($admin instanceof JsonResponse) {
            return $admin;
        }

        $payload = $request->validate([
            'status' => ['required', Rule::in(['approved', 'rejected', 'expired'])],
            'rejection_reason' => ['nullable', 'string', 'max:255'],
        ]);

        $result = DB::transaction(function () use ($documentId, $payload, $admin) {
            $document = DB::table('driver_documents')
                ->where('id', $documentId)
                ->lockForUpdate()
                ->first();

            if ($document === null) {
                return response()->json([
                    'status' => 'error',
                    'message' => 'Driver document not found.',
                ], 404);
            }

            if ((string) $payload['status'] === 'rejected' && blank($payload['rejection_reason'] ?? null)) {
                return response()->json([
                    'status' => 'error',
                    'message' => 'A rejection reason is required when rejecting a document.',
                    'errors' => [
                        'rejection_reason' => ['A rejection reason is required when rejecting a document.'],
                    ],
                ], 422);
            }

            $now = now();

            DB::table('driver_documents')
                ->where('id', $documentId)
                ->update([
                    'status' => $payload['status'],
                    'reviewed_by_user_id' => $admin->id,
                    'reviewed_at' => $now,
                    'rejection_reason' => (string) $payload['status'] === 'rejected'
                        ? trim((string) $payload['rejection_reason'])
                        : null,
                    'updated_at' => $now,
                ]);

            $this->refreshDriverReviewState((int) $document->driver_profile_id, $now);

            $profile = $this->baseProfileQuery()
                ->where('dp.id', (int) $document->driver_profile_id)
                ->first();

            return response()->json([
                'status' => 'ok',
                'message' => 'Driver document review updated.',
                'application' => $profile ? $this->serializeDetail($profile) : null,
            ]);
        });

        if ($result->getStatusCode() === 200) {
            $document = DB::table('driver_documents as dd')
                ->join('driver_profiles as dp', 'dp.id', '=', 'dd.driver_profile_id')
                ->where('dd.id', $documentId)
                ->first([
                    'dd.document_type',
                    'dd.status',
                    'dd.rejection_reason',
                    'dp.user_id',
                ]);

            if ($document !== null) {
                $documentLabel = Str::headline(str_replace('_', ' ', (string) $document->document_type));
                $body = match ((string) $document->status) {
                    'approved' => $documentLabel . ' was approved.',
                    'rejected' => $documentLabel . ' needs attention. Review the note and upload it again.',
                    'expired' => $documentLabel . ' expired and needs to be uploaded again.',
                    default => $documentLabel . ' status was updated.',
                };

                $pushNotificationService->sendToUsers(
                    [(int) $document->user_id],
                    title: 'Document review updated',
                    body: $body,
                    data: [
                        'channel' => 'driver_onboarding',
                        'type' => 'document_status_changed',
                        'document_type' => (string) $document->document_type,
                        'status' => (string) $document->status,
                    ],
                );
            }
        }

        return $result;
    }

    public function updateApplicationStatus(
        Request $request,
        int $driverProfileId,
        FirebaseTokenVerifier $tokenVerifier,
        FirebaseUserSyncService $userSyncService,
        PushNotificationService $pushNotificationService
    ): JsonResponse {
        $admin = $this->resolveAdminUser($request, $tokenVerifier, $userSyncService);
        if ($admin instanceof JsonResponse) {
            return $admin;
        }

        $payload = $request->validate([
            'decision' => ['required', Rule::in(['approve', 'reject', 'suspend', 'reopen'])],
            'note' => ['nullable', 'string', 'max:500'],
        ]);

        $result = DB::transaction(function () use ($driverProfileId, $payload, $admin) {
            $profile = DB::table('driver_profiles')
                ->where('id', $driverProfileId)
                ->lockForUpdate()
                ->first();

            if ($profile === null) {
                return response()->json([
                    'status' => 'error',
                    'message' => 'Driver application not found.',
                ], 404);
            }

            $decision = (string) $payload['decision'];
            $note = isset($payload['note']) && trim((string) $payload['note']) !== ''
                ? trim((string) $payload['note'])
                : null;
            $now = now();

            if ($decision === 'approve') {
                $issues = $this->approvalIssues((int) $driverProfileId);

                if ($issues !== []) {
                    return response()->json([
                        'status' => 'error',
                        'message' => 'This driver cannot be approved yet.',
                        'issues' => $issues,
                    ], 422);
                }

                DB::table('driver_profiles')
                    ->where('id', $driverProfileId)
                    ->update([
                        'status' => 'active',
                        'onboarding_status' => 'approved',
                        'updated_at' => $now,
                        'notes' => $this->appendAdminNote($profile->notes, $admin->email ?? 'admin', 'Approved driver application.', $note),
                    ]);
            } elseif ($decision === 'reject') {
                if ($note === null) {
                    return response()->json([
                        'status' => 'error',
                        'message' => 'A rejection note is required.',
                        'errors' => [
                            'note' => ['A rejection note is required.'],
                        ],
                    ], 422);
                }

                DB::table('driver_profiles')
                    ->where('id', $driverProfileId)
                    ->update([
                        'status' => 'rejected',
                        'onboarding_status' => 'rejected',
                        'is_online' => 0,
                        'is_busy' => 0,
                        'updated_at' => $now,
                        'notes' => $this->appendAdminNote($profile->notes, $admin->email ?? 'admin', 'Rejected driver application.', $note),
                    ]);
            } elseif ($decision === 'suspend') {
                DB::table('driver_profiles')
                    ->where('id', $driverProfileId)
                    ->update([
                        'status' => 'suspended',
                        'is_online' => 0,
                        'is_busy' => 0,
                        'updated_at' => $now,
                        'notes' => $this->appendAdminNote($profile->notes, $admin->email ?? 'admin', 'Suspended driver access.', $note),
                    ]);
            } else {
                DB::table('driver_profiles')
                    ->where('id', $driverProfileId)
                    ->update([
                        'status' => 'pending',
                        'onboarding_status' => 'review',
                        'is_online' => 0,
                        'is_busy' => 0,
                        'updated_at' => $now,
                        'notes' => $this->appendAdminNote($profile->notes, $admin->email ?? 'admin', 'Reopened driver application for review.', $note),
                    ]);
            }

            $updated = $this->baseProfileQuery()
                ->where('dp.id', $driverProfileId)
                ->first();

            return response()->json([
                'status' => 'ok',
                'message' => 'Driver application updated.',
                'application' => $updated ? $this->serializeDetail($updated) : null,
            ]);
        });

        if ($result->getStatusCode() === 200) {
            $profile = DB::table('driver_profiles as dp')
                ->join('users as u', 'u.id', '=', 'dp.user_id')
                ->where('dp.id', $driverProfileId)
                ->first([
                    'u.id as user_id',
                    'dp.status',
                    'dp.onboarding_status',
                ]);

            if ($profile !== null) {
                $decision = (string) $payload['decision'];
                $body = match ($decision) {
                    'approve' => 'Your driver account is approved. You can now go online and receive requests.',
                    'reject' => 'Your driver application needs updates before approval. Review the latest notes and resubmit.',
                    'suspend' => 'Your driver access was suspended. Contact support if you need assistance.',
                    'reopen' => 'Your driver application was reopened for review. Complete the requested updates to continue.',
                    default => 'Your driver onboarding status changed.',
                };

                $pushNotificationService->sendToUsers(
                    [(int) $profile->user_id],
                    title: 'Driver application updated',
                    body: $body,
                    data: [
                        'channel' => 'driver_onboarding',
                        'type' => 'application_status_changed',
                        'status' => (string) $profile->status,
                        'onboarding_status' => (string) $profile->onboarding_status,
                    ],
                );
            }
        }

        return $result;
    }

    private function driverApplicationsQuery(array $filters)
    {
        $query = $this->baseProfileQuery();

        $state = $filters['state'] ?? 'pending';
        if ($state === 'pending') {
            $query->whereIn('dp.onboarding_status', ['documents_pending', 'review']);
        } elseif ($state === 'review') {
            $query->where('dp.onboarding_status', 'review');
        } elseif ($state === 'approved') {
            $query->where('dp.onboarding_status', 'approved');
        } elseif ($state === 'rejected') {
            $query->where(function ($builder): void {
                $builder
                    ->where('dp.onboarding_status', 'rejected')
                    ->orWhere('dp.status', 'rejected');
            });
        } elseif ($state === 'suspended') {
            $query->where('dp.status', 'suspended');
        }

        if (($filters['q'] ?? null) !== null && trim((string) $filters['q']) !== '') {
            $search = trim((string) $filters['q']);
            $query->where(function ($builder) use ($search): void {
                $builder
                    ->where('u.full_name', 'like', '%' . $search . '%')
                    ->orWhere('u.email', 'like', '%' . $search . '%')
                    ->orWhere('u.phone', 'like', '%' . $search . '%')
                    ->orWhere('dp.driver_code', 'like', '%' . $search . '%')
                    ->orWhere('dp.license_number', 'like', '%' . $search . '%');
            });
        }

        if (isset($filters['city_id'])) {
            $query->where('dp.city_id', (int) $filters['city_id']);
        }

        return $query;
    }

    private function baseProfileQuery()
    {
        return DB::table('driver_profiles as dp')
            ->join('users as u', 'u.id', '=', 'dp.user_id')
            ->leftJoin('cities as c', 'c.id', '=', 'dp.city_id')
            ->select([
                'dp.id',
                'dp.user_id',
                'dp.driver_code',
                'dp.license_number',
                'dp.status',
                'dp.onboarding_status',
                'dp.is_online',
                'dp.is_busy',
                'dp.rating_average',
                'dp.rating_count',
                'dp.trips_completed',
                'dp.notes',
                'dp.created_at',
                'dp.updated_at',
                'u.full_name',
                'u.email',
                'u.phone',
                'u.country_code',
                'u.national_id_number',
                'c.id as city_id',
                'c.name as city_name',
            ]);
    }

    private function buildSummary(): array
    {
        $base = DB::table('driver_profiles');

        return [
            'pending_review' => (clone $base)
                ->whereIn('onboarding_status', ['documents_pending', 'review'])
                ->count(),
            'approved' => (clone $base)
                ->where('onboarding_status', 'approved')
                ->count(),
            'rejected' => (clone $base)
                ->where('onboarding_status', 'rejected')
                ->count(),
            'suspended' => (clone $base)
                ->where('status', 'suspended')
                ->count(),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function serializeListItem(object $profile): array
    {
        $documents = $this->documentsForProfile((int) $profile->id);
        $services = $this->servicesForProfile((int) $profile->id);

        return [
            'id' => (int) $profile->id,
            'driver_code' => $profile->driver_code,
            'full_name' => $profile->full_name,
            'email' => $profile->email,
            'phone' => $profile->phone,
            'city_name' => $profile->city_name,
            'status' => $profile->status,
            'onboarding_status' => $profile->onboarding_status,
            'status_label' => Str::headline(str_replace('_', ' ', (string) $profile->onboarding_status)),
            'document_summary' => [
                'total' => count($documents),
                'approved' => count(array_filter($documents, fn (array $document): bool => $document['status'] === 'approved')),
                'pending' => count(array_filter($documents, fn (array $document): bool => $document['status'] === 'pending')),
                'rejected' => count(array_filter($documents, fn (array $document): bool => $document['status'] === 'rejected')),
            ],
            'service_types' => array_map(fn (array $service): string => $service['name'], $services),
            'updated_at' => $profile->updated_at,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function serializeDetail(object $profile): array
    {
        $documents = $this->documentsForProfile((int) $profile->id, true);
        $services = $this->servicesForProfile((int) $profile->id);
        $vehicle = $this->vehicleForProfile((int) $profile->id);

        return [
            'id' => (int) $profile->id,
            'user' => [
                'id' => (int) $profile->user_id,
                'full_name' => $profile->full_name,
                'email' => $profile->email,
                'phone' => $profile->phone,
                'country_code' => $profile->country_code,
                'national_id_number' => $profile->national_id_number,
            ],
            'driver_code' => $profile->driver_code,
            'license_number' => $profile->license_number,
            'status' => $profile->status,
            'onboarding_status' => $profile->onboarding_status,
            'status_label' => Str::headline(str_replace('_', ' ', (string) $profile->onboarding_status)),
            'city' => [
                'id' => $profile->city_id !== null ? (int) $profile->city_id : null,
                'name' => $profile->city_name,
            ],
            'rating_average' => (float) $profile->rating_average,
            'rating_count' => (int) $profile->rating_count,
            'trips_completed' => (int) $profile->trips_completed,
            'services' => $services,
            'vehicle' => $vehicle,
            'documents' => $documents,
            'approval_issues' => $this->approvalIssues((int) $profile->id),
            'notes' => $profile->notes,
            'created_at' => $profile->created_at,
            'updated_at' => $profile->updated_at,
        ];
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function documentsForProfile(int $driverProfileId, bool $withPreviewUrl = false): array
    {
        return DB::table('driver_documents as dd')
            ->leftJoin('users as reviewer', 'reviewer.id', '=', 'dd.reviewed_by_user_id')
            ->where('dd.driver_profile_id', $driverProfileId)
            ->orderBy('dd.document_type')
            ->get([
                'dd.id',
                'dd.document_type',
                'dd.document_number',
                'dd.status',
                'dd.expiry_date',
                'dd.reviewed_at',
                'dd.rejection_reason',
                'reviewer.email as reviewed_by_email',
            ])
            ->map(function (object $document) use ($withPreviewUrl): array {
                $payload = [
                    'id' => (int) $document->id,
                    'document_type' => (string) $document->document_type,
                    'document_label' => Str::headline(str_replace('_', ' ', (string) $document->document_type)),
                    'document_number' => $document->document_number,
                    'status' => (string) $document->status,
                    'expiry_date' => $document->expiry_date,
                    'reviewed_at' => $document->reviewed_at,
                    'reviewed_by_email' => $document->reviewed_by_email,
                    'rejection_reason' => $document->rejection_reason,
                ];

                if ($withPreviewUrl) {
                    $payload['preview_endpoint'] = route('api.onboarding.driver-documents.show', [
                        'documentId' => $document->id,
                    ], false);
                }

                return $payload;
            })
            ->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function servicesForProfile(int $driverProfileId): array
    {
        return DB::table('driver_service_enablements as dse')
            ->join('service_types as st', 'st.id', '=', 'dse.service_type_id')
            ->where('dse.driver_profile_id', $driverProfileId)
            ->orderBy('st.sort_order')
            ->orderBy('st.name')
            ->get([
                'st.id',
                'st.name',
                'st.slug',
                'dse.is_enabled',
            ])
            ->map(fn (object $service): array => [
                'id' => (int) $service->id,
                'name' => (string) $service->name,
                'slug' => (string) $service->slug,
                'is_enabled' => (bool) $service->is_enabled,
            ])
            ->all();
    }

    /**
     * @return array<string, mixed>|null
     */
    private function vehicleForProfile(int $driverProfileId): ?array
    {
        $vehicle = DB::table('driver_vehicle_assignments as dva')
            ->join('vehicles as v', 'v.id', '=', 'dva.vehicle_id')
            ->leftJoin('vehicle_types as vt', 'vt.id', '=', 'v.vehicle_type_id')
            ->leftJoin('vehicle_makes as vmk', 'vmk.id', '=', 'v.vehicle_make_id')
            ->leftJoin('vehicle_models as vmd', 'vmd.id', '=', 'v.vehicle_model_id')
            ->where('dva.driver_profile_id', $driverProfileId)
            ->where('dva.is_current', 1)
            ->orderByDesc('dva.starts_at')
            ->first([
                'v.id',
                'v.plate_number',
                'v.color',
                'v.year_of_manufacture',
                'v.seats',
                'v.fuel_type',
                'v.status',
                'vt.name as vehicle_type_name',
                'vmk.name as vehicle_make_name',
                'vmd.name as vehicle_model_name',
            ]);

        if ($vehicle === null) {
            return null;
        }

        return [
            'id' => (int) $vehicle->id,
            'plate_number' => $vehicle->plate_number,
            'color' => $vehicle->color,
            'year_of_manufacture' => $vehicle->year_of_manufacture,
            'seats' => $vehicle->seats,
            'fuel_type' => $vehicle->fuel_type,
            'status' => $vehicle->status,
            'label' => trim(collect([
                $vehicle->vehicle_make_name,
                $vehicle->vehicle_model_name,
                $vehicle->vehicle_type_name,
            ])->filter()->implode(' ')),
        ];
    }

    /**
     * @return array<int, string>
     */
    private function approvalIssues(int $driverProfileId): array
    {
        $documents = collect($this->documentsForProfile($driverProfileId));
        $vehicle = $this->vehicleForProfile($driverProfileId);
        $issues = [];

        foreach (self::REQUIRED_DOCUMENT_TYPES as $documentType) {
            $document = $documents->first(fn (array $item): bool => $item['document_type'] === $documentType);

            if ($document === null) {
                $issues[] = Str::headline(str_replace('_', ' ', $documentType)) . ' is missing.';
                continue;
            }

            if ($document['status'] !== 'approved') {
                $issues[] = Str::headline(str_replace('_', ' ', $documentType)) . ' must be approved first.';
            }
        }

        if ($vehicle !== null) {
            $vehicleRegistration = $documents->first(
                fn (array $item): bool => $item['document_type'] === 'vehicle_registration'
            );

            if ($vehicleRegistration === null) {
                $issues[] = 'Vehicle registration document is missing.';
            } elseif ($vehicleRegistration['status'] !== 'approved') {
                $issues[] = 'Vehicle registration document must be approved first.';
            }
        }

        return array_values(array_unique($issues));
    }

    private function refreshDriverReviewState(int $driverProfileId, $now): void
    {
        $profile = DB::table('driver_profiles')
            ->where('id', $driverProfileId)
            ->first(['status', 'onboarding_status']);

        if ($profile === null) {
            return;
        }

        if ((string) $profile->onboarding_status === 'approved' || (string) $profile->status === 'rejected') {
            return;
        }

        $hasDocuments = DB::table('driver_documents')
            ->where('driver_profile_id', $driverProfileId)
            ->exists();

        DB::table('driver_profiles')
            ->where('id', $driverProfileId)
            ->update([
                'onboarding_status' => $hasDocuments ? 'review' : 'documents_pending',
                'updated_at' => $now,
            ]);
    }

    private function appendAdminNote(?string $existingNotes, string $actor, string $action, ?string $detail): string
    {
        $parts = [];

        if ($existingNotes !== null && trim($existingNotes) !== '') {
            $parts[] = trim($existingNotes);
        }

        $entry = '[' . now()->toDateTimeString() . '] ' . $actor . ' - ' . $action;
        if ($detail !== null && trim($detail) !== '') {
            $entry .= ' ' . trim($detail);
        }

        $parts[] = $entry;

        return implode(PHP_EOL, $parts);
    }
}
