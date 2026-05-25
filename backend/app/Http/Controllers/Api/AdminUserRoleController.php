<?php

namespace App\Http\Controllers\Api;

use App\Contracts\Auth\FirebaseTokenVerifier;
use App\Http\Controllers\Api\Concerns\ResolvesAdminRequestUser;
use App\Http\Controllers\Controller;
use App\Services\Auth\FirebaseUserSyncService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class AdminUserRoleController extends Controller
{
    use ResolvesAdminRequestUser;

    private const MANAGEABLE_ACCESS_ROLES = [
        'rider',
        'support',
        'admin',
    ];

    public function index(
        Request $request,
        FirebaseTokenVerifier $tokenVerifier,
        FirebaseUserSyncService $userSyncService
    ): JsonResponse {
        $admin = $this->resolveSuperAdminUser($request, $tokenVerifier, $userSyncService);
        if ($admin instanceof JsonResponse) {
            return $admin;
        }

        $filters = $request->validate([
            'q' => ['nullable', 'string', 'max:191'],
        ]);

        $query = DB::table('users')
            ->select([
                'id',
                'full_name',
                'email',
                'phone',
                'role',
                'status',
                'last_login_at',
            ])
            ->where('status', '!=', 'deleted');

        $search = trim((string) ($filters['q'] ?? ''));
        if ($search !== '') {
            $query->where(function ($builder) use ($search): void {
                $builder
                    ->where('full_name', 'like', '%' . $search . '%')
                    ->orWhere('email', 'like', '%' . $search . '%')
                    ->orWhere('phone', 'like', '%' . $search . '%');
            });
        }

        $users = $query
            ->orderByDesc('last_login_at')
            ->orderBy('full_name')
            ->limit(25)
            ->get();

        return response()->json([
            'status' => 'ok',
            'viewer' => [
                'id' => $admin->id,
                'email' => $admin->email,
                'role' => $admin->role,
                'can_manage_admins' => true,
            ],
            'filters' => [
                'q' => $search !== '' ? $search : null,
            ],
            'available_roles' => self::MANAGEABLE_ACCESS_ROLES,
            'primary_admin_email' => config('onwayrides.super_admin_email'),
            'data' => $users->map(fn (object $user): array => $this->serializeUser($user))->all(),
        ]);
    }

    public function updateRole(
        Request $request,
        int $userId,
        FirebaseTokenVerifier $tokenVerifier,
        FirebaseUserSyncService $userSyncService
    ): JsonResponse {
        $admin = $this->resolveSuperAdminUser($request, $tokenVerifier, $userSyncService);
        if ($admin instanceof JsonResponse) {
            return $admin;
        }

        $payload = $request->validate([
            'role' => ['required', Rule::in(self::MANAGEABLE_ACCESS_ROLES)],
            'note' => ['nullable', 'string', 'max:255'],
        ]);

        $result = DB::transaction(function () use ($admin, $payload, $request, $userId) {
            $target = DB::table('users')
                ->where('id', $userId)
                ->lockForUpdate()
                ->first();

            if ($target === null) {
                return response()->json([
                    'status' => 'error',
                    'message' => 'User not found.',
                ], 404);
            }

            if ((int) $target->id === (int) $admin->id) {
                return response()->json([
                    'status' => 'error',
                    'message' => 'Use phpMyAdmin or SQL if you ever need to change the primary admin account. Self role changes are blocked here.',
                ], 422);
            }

            if ($this->isProtectedPrimaryAdmin($target)) {
                return response()->json([
                    'status' => 'error',
                    'message' => 'The primary admin account cannot be edited from this panel.',
                ], 422);
            }

            $nextRole = (string) $payload['role'];
            $currentRole = (string) $target->role;

            if (
                in_array($currentRole, ['driver', 'fleet_owner', 'merchant'], true)
                && in_array($nextRole, ['admin', 'support'], true)
            ) {
                return response()->json([
                    'status' => 'error',
                    'message' => 'This account already has an operational marketplace role. Create a separate admin account instead of replacing that role.',
                ], 422);
            }

            $now = now();
            $nextStatus = in_array($nextRole, ['admin', 'support'], true) && (string) $target->status === 'pending'
                ? 'active'
                : (string) $target->status;

            DB::table('users')
                ->where('id', $userId)
                ->update([
                    'role' => $nextRole,
                    'status' => $nextStatus,
                    'updated_at' => $now,
                ]);

            $note = trim((string) ($payload['note'] ?? ''));

            DB::table('admin_audit_logs')->insert([
                'admin_user_id' => $admin->id,
                'action' => 'user.role.updated',
                'entity_type' => 'user',
                'entity_id' => $userId,
                'note' => $note !== ''
                    ? $note
                    : sprintf(
                        'Changed user role from %s to %s.',
                        $currentRole,
                        $nextRole
                    ),
                'before_json' => json_encode([
                    'role' => $currentRole,
                    'status' => $target->status,
                    'email' => $target->email,
                ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
                'after_json' => json_encode([
                    'role' => $nextRole,
                    'status' => $nextStatus,
                    'email' => $target->email,
                ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
                'ip_address' => $request->ip(),
                'created_at' => $now,
            ]);

            $updated = DB::table('users')
                ->select([
                    'id',
                    'full_name',
                    'email',
                    'phone',
                    'role',
                    'status',
                    'last_login_at',
                ])
                ->where('id', $userId)
                ->first();

            return response()->json([
                'status' => 'ok',
                'message' => 'User access role updated.',
                'user' => $updated ? $this->serializeUser($updated) : null,
            ]);
        });

        return $result;
    }

    private function serializeUser(object $user): array
    {
        return [
            'id' => (int) $user->id,
            'full_name' => $user->full_name,
            'email' => $user->email,
            'phone' => $user->phone,
            'role' => $user->role,
            'status' => $user->status,
            'last_login_at' => $user->last_login_at,
            'is_primary_admin' => $this->isPrimaryAdminEmail($user->email),
            'can_promote_to_admin' => ! in_array((string) $user->role, ['driver', 'fleet_owner', 'merchant'], true),
        ];
    }

    private function isProtectedPrimaryAdmin(object $user): bool
    {
        return $this->isPrimaryAdminEmail($user->email);
    }

    private function isPrimaryAdminEmail(?string $email): bool
    {
        $configuredEmail = Str::lower(trim((string) config('onwayrides.super_admin_email', '')));
        $candidate = Str::lower(trim((string) $email));

        return $configuredEmail !== '' && $candidate === $configuredEmail;
    }
}
