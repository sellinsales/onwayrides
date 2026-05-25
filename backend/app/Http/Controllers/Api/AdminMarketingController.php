<?php

namespace App\Http\Controllers\Api;

use App\Contracts\Auth\FirebaseTokenVerifier;
use App\Http\Controllers\Api\Concerns\ResolvesAdminRequestUser;
use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\Auth\FirebaseUserSyncService;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\StreamedResponse;

class AdminMarketingController extends Controller
{
    use ResolvesAdminRequestUser;

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
            'channel' => ['nullable', 'in:all,whatsapp,sms,unsubscribed'],
            'platform' => ['nullable', 'in:all,web,android,ios,unknown'],
        ]);

        $query = $this->marketingAudienceQuery($filters);

        $contacts = $query
            ->orderByDesc('created_at')
            ->limit(500)
            ->get()
            ->map(fn (User $user) => $this->serializeContact($user))
            ->values();

        return response()->json([
            'status' => 'ok',
            'viewer' => [
                'id' => $admin->id,
                'email' => $admin->email,
                'role' => $admin->role,
            ],
            'filters' => [
                'q' => $filters['q'] ?? null,
                'channel' => $filters['channel'] ?? 'all',
                'platform' => $filters['platform'] ?? 'all',
            ],
            'summary' => $this->buildSummary(),
            'data' => $contacts,
        ]);
    }

    public function export(
        Request $request,
        FirebaseTokenVerifier $tokenVerifier,
        FirebaseUserSyncService $userSyncService
    ): JsonResponse|StreamedResponse {
        $admin = $this->resolveAdminUser($request, $tokenVerifier, $userSyncService);
        if ($admin instanceof JsonResponse) {
            return $admin;
        }

        $filters = $request->validate([
            'q' => ['nullable', 'string', 'max:191'],
            'channel' => ['nullable', 'in:all,whatsapp,sms,unsubscribed'],
            'platform' => ['nullable', 'in:all,web,android,ios,unknown'],
        ]);

        $query = $this->marketingAudienceQuery($filters)->orderByDesc('created_at');
        $fileName = 'onwayrides-marketing-audience-' . now()->format('Ymd-His') . '.csv';

        return response()->streamDownload(function () use ($query): void {
            $handle = fopen('php://output', 'w');
            if ($handle === false) {
                return;
            }

            fputcsv($handle, [
                'id',
                'full_name',
                'email',
                'phone',
                'country_code',
                'role',
                'status',
                'phone_verified',
                'platform',
                'whatsapp_marketing_opt_in',
                'sms_marketing_opt_in',
                'privacy_policy_accepted_at',
                'terms_of_service_accepted_at',
                'created_at',
                'last_login_at',
            ]);

            $query->chunk(200, function ($users) use ($handle): void {
                foreach ($users as $user) {
                    $contact = $this->serializeContact($user);
                    fputcsv($handle, [
                        $contact['id'],
                        $contact['full_name'],
                        $contact['email'],
                        $contact['phone'],
                        $contact['country_code'],
                        $contact['role'],
                        $contact['status'],
                        $contact['phone_verified'] ? 'yes' : 'no',
                        $contact['platform'],
                        $contact['whatsapp_marketing_opt_in'] ? 'yes' : 'no',
                        $contact['sms_marketing_opt_in'] ? 'yes' : 'no',
                        $contact['privacy_policy_accepted_at'],
                        $contact['terms_of_service_accepted_at'],
                        $contact['created_at'],
                        $contact['last_login_at'],
                    ]);
                }
            });

            fclose($handle);
        }, $fileName, [
            'Content-Type' => 'text/csv; charset=UTF-8',
        ]);
    }

    private function marketingAudienceQuery(array $filters): Builder
    {
        $query = User::query()
            ->where(function (Builder $builder): void {
                $builder
                    ->whereNotNull('email')
                    ->orWhereNotNull('phone')
                    ->orWhereNotNull('firebase_uid');
            });

        if (($filters['q'] ?? null) !== null && trim((string) $filters['q']) !== '') {
            $search = trim((string) $filters['q']);
            $query->where(function (Builder $builder) use ($search): void {
                $builder
                    ->where('full_name', 'like', '%' . $search . '%')
                    ->orWhere('email', 'like', '%' . $search . '%')
                    ->orWhere('phone', 'like', '%' . $search . '%');
            });
        }

        $channel = $filters['channel'] ?? 'all';
        if ($channel === 'whatsapp') {
            $query->where('metadata->whatsapp_marketing_opt_in', true);
        } elseif ($channel === 'sms') {
            $query->where('metadata->sms_marketing_opt_in', true);
        } elseif ($channel === 'unsubscribed') {
            $query
                ->where(function (Builder $builder): void {
                    $builder->whereNull('metadata->whatsapp_marketing_opt_in')
                        ->orWhere('metadata->whatsapp_marketing_opt_in', false);
                })
                ->where(function (Builder $builder): void {
                    $builder->whereNull('metadata->sms_marketing_opt_in')
                        ->orWhere('metadata->sms_marketing_opt_in', false);
                });
        }

        $platform = $filters['platform'] ?? 'all';
        if ($platform !== 'all') {
            if ($platform === 'unknown') {
                $query->whereNull('metadata->last_sign_in_platform');
            } else {
                $query->where('metadata->last_sign_in_platform', $platform);
            }
        }

        return $query;
    }

    private function buildSummary(): array
    {
        $baseQuery = User::query()
            ->where(function (Builder $builder): void {
                $builder
                    ->whereNotNull('email')
                    ->orWhereNotNull('phone')
                    ->orWhereNotNull('firebase_uid');
            });

        return [
            'registered_users' => (clone $baseQuery)->count(),
            'whatsapp_opted_in' => (clone $baseQuery)
                ->where('metadata->whatsapp_marketing_opt_in', true)
                ->count(),
            'sms_opted_in' => (clone $baseQuery)
                ->where('metadata->sms_marketing_opt_in', true)
                ->count(),
            'phone_verified' => (clone $baseQuery)
                ->whereNotNull('phone_verified_at')
                ->count(),
            'web_sign_ins' => (clone $baseQuery)
                ->where('metadata->last_sign_in_platform', 'web')
                ->count(),
            'android_sign_ins' => (clone $baseQuery)
                ->where('metadata->last_sign_in_platform', 'android')
                ->count(),
        ];
    }

    private function serializeContact(User $user): array
    {
        $metadata = is_array($user->metadata) ? $user->metadata : [];

        return [
            'id' => $user->id,
            'full_name' => $user->full_name,
            'email' => $user->email,
            'phone' => $user->phone,
            'country_code' => $user->country_code,
            'role' => $user->role,
            'status' => $user->status,
            'platform' => $metadata['last_sign_in_platform'] ?? 'unknown',
            'phone_verified' => $user->phone_verified_at !== null,
            'whatsapp_marketing_opt_in' => (bool) ($metadata['whatsapp_marketing_opt_in'] ?? false),
            'sms_marketing_opt_in' => (bool) ($metadata['sms_marketing_opt_in'] ?? false),
            'privacy_policy_accepted_at' => $metadata['privacy_policy_accepted_at'] ?? null,
            'terms_of_service_accepted_at' => $metadata['terms_of_service_accepted_at'] ?? null,
            'created_at' => optional($user->created_at)->toIso8601String(),
            'last_login_at' => optional($user->last_login_at)->toIso8601String(),
        ];
    }
}
