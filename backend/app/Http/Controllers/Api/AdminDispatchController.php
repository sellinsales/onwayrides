<?php

namespace App\Http\Controllers\Api;

use App\Contracts\Auth\FirebaseTokenVerifier;
use App\Http\Controllers\Api\Concerns\ResolvesAdminRequestUser;
use App\Http\Controllers\Controller;
use App\Services\Auth\FirebaseUserSyncService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class AdminDispatchController extends Controller
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
            'status' => ['nullable', Rule::in(['open', 'unassigned', 'active', 'scheduled', 'completed', 'cancelled'])],
            'city_id' => ['nullable', 'integer', Rule::exists('cities', 'id')],
        ]);

        $rows = $this->dispatchQuery($filters)
            ->orderByRaw("FIELD(b.booking_status, 'pending', 'searching', 'offered', 'accepted', 'arriving', 'in_progress', 'scheduled', 'completed', 'cancelled')")
            ->orderByDesc('b.requested_at')
            ->limit(50)
            ->get();

        return response()->json([
            'status' => 'ok',
            'viewer' => [
                'id' => $admin->id,
                'email' => $admin->email,
                'role' => $admin->role,
            ],
            'filters' => [
                'q' => $filters['q'] ?? null,
                'status' => $filters['status'] ?? 'open',
                'city_id' => isset($filters['city_id']) ? (int) $filters['city_id'] : null,
            ],
            'summary' => $this->buildSummary(),
            'data' => $rows->map(fn (object $booking): array => $this->serializeRow($booking))->all(),
        ]);
    }

    private function dispatchQuery(array $filters)
    {
        $query = DB::table('bookings as b')
            ->join('service_types as st', 'st.id', '=', 'b.service_type_id')
            ->leftJoin('cities as c', 'c.id', '=', 'b.city_id')
            ->join('users as rider', 'rider.id', '=', 'b.rider_user_id')
            ->leftJoin('driver_profiles as dp', 'dp.id', '=', 'b.driver_profile_id')
            ->leftJoin('users as driver', 'driver.id', '=', 'dp.user_id')
            ->select([
                'b.id',
                'b.booking_reference',
                'b.booking_status',
                'b.payment_method',
                'b.estimated_fare',
                'b.offered_fare',
                'b.final_fare',
                'b.pickup_address',
                'b.destination_address',
                'b.requested_at',
                'b.scheduled_for',
                'b.accepted_at',
                'b.driver_profile_id',
                'st.name as service_name',
                'st.slug as service_slug',
                'c.name as city_name',
                'rider.full_name as rider_name',
                'rider.phone as rider_phone',
                'driver.full_name as driver_name',
                DB::raw('TIMESTAMPDIFF(MINUTE, b.requested_at, NOW()) as queue_age_minutes'),
            ]);

        $status = $filters['status'] ?? 'open';
        if ($status === 'open') {
            $query->whereIn('b.booking_status', ['pending', 'searching', 'offered', 'accepted', 'arriving', 'in_progress', 'scheduled']);
        } elseif ($status === 'unassigned') {
            $query
                ->whereNull('b.driver_profile_id')
                ->whereIn('b.booking_status', ['pending', 'searching', 'offered', 'scheduled']);
        } elseif ($status === 'active') {
            $query->whereIn('b.booking_status', ['accepted', 'arriving', 'in_progress']);
        } else {
            $query->where('b.booking_status', $status);
        }

        if (($filters['q'] ?? null) !== null && trim((string) $filters['q']) !== '') {
            $search = trim((string) $filters['q']);
            $query->where(function ($builder) use ($search): void {
                $builder
                    ->where('b.booking_reference', 'like', '%' . $search . '%')
                    ->orWhere('rider.full_name', 'like', '%' . $search . '%')
                    ->orWhere('rider.phone', 'like', '%' . $search . '%')
                    ->orWhere('driver.full_name', 'like', '%' . $search . '%')
                    ->orWhere('b.pickup_address', 'like', '%' . $search . '%')
                    ->orWhere('b.destination_address', 'like', '%' . $search . '%');
            });
        }

        if (isset($filters['city_id'])) {
            $query->where('b.city_id', (int) $filters['city_id']);
        }

        return $query;
    }

    private function buildSummary(): array
    {
        $base = DB::table('bookings');

        return [
            'open_unassigned' => (clone $base)
                ->whereNull('driver_profile_id')
                ->whereIn('booking_status', ['pending', 'searching', 'offered', 'scheduled'])
                ->count(),
            'active_trips' => (clone $base)
                ->whereIn('booking_status', ['accepted', 'arriving', 'in_progress'])
                ->count(),
            'scheduled' => (clone $base)
                ->where('booking_status', 'scheduled')
                ->count(),
            'completed_today' => (clone $base)
                ->where('booking_status', 'completed')
                ->whereDate('completed_at', Carbon::today())
                ->count(),
            'online_drivers' => DB::table('driver_profiles')
                ->where('status', 'active')
                ->where('onboarding_status', 'approved')
                ->where('is_online', 1)
                ->count(),
            'busy_drivers' => DB::table('driver_profiles')
                ->where('status', 'active')
                ->where('onboarding_status', 'approved')
                ->where('is_busy', 1)
                ->count(),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function serializeRow(object $booking): array
    {
        $scheduledFor = $booking->scheduled_for !== null
            ? Carbon::parse((string) $booking->scheduled_for)
            : null;

        return [
            'id' => (int) $booking->id,
            'reference' => (string) $booking->booking_reference,
            'status' => (string) $booking->booking_status,
            'status_label' => Str::headline(str_replace('_', ' ', (string) $booking->booking_status)),
            'service_name' => (string) $booking->service_name,
            'service_slug' => (string) $booking->service_slug,
            'city_name' => $booking->city_name,
            'rider_name' => (string) $booking->rider_name,
            'rider_phone' => $booking->rider_phone,
            'driver_name' => $booking->driver_name,
            'pickup_address' => (string) $booking->pickup_address,
            'destination_address' => (string) $booking->destination_address,
            'payment_method' => (string) $booking->payment_method,
            'fare_label' => $this->formatFareLabel($booking),
            'requested_at' => $booking->requested_at,
            'scheduled_for' => $scheduledFor?->toIso8601String(),
            'queue_age_minutes' => max(0, (int) ($booking->queue_age_minutes ?? 0)),
            'needs_attention' => $booking->driver_profile_id === null
                && in_array((string) $booking->booking_status, ['pending', 'searching', 'offered'], true)
                && (int) ($booking->queue_age_minutes ?? 0) >= 10,
        ];
    }

    private function formatFareLabel(object $booking): string
    {
        $amount = $booking->final_fare
            ?? $booking->offered_fare
            ?? $booking->estimated_fare;

        if ($amount === null) {
            return 'Fare pending';
        }

        return 'PKR ' . number_format((float) $amount, 0);
    }
}
