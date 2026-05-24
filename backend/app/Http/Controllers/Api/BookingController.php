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
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class BookingController extends Controller
{
    use ResolvesFirebaseRequestUser;

    private const ACTIVE_STATUSES = [
        'pending',
        'searching',
        'offered',
        'accepted',
        'arriving',
        'in_progress',
        'scheduled',
    ];

    public function index(
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

        $bookings = $this->baseBookingQuery($user->id)
            ->orderByDesc('b.requested_at')
            ->limit(20)
            ->get();

        $activeBooking = $bookings->first(
            fn (object $booking): bool => in_array($booking->booking_status, self::ACTIVE_STATUSES, true)
        );

        return response()->json([
            'status' => 'ok',
            'active_booking' => $activeBooking ? $this->serializeBooking($activeBooking) : null,
            'history' => $bookings
                ->filter(fn (object $booking): bool => $activeBooking === null || (int) $booking->id !== (int) $activeBooking->id)
                ->values()
                ->map(fn (object $booking): array => $this->serializeBooking($booking))
                ->all(),
        ]);
    }

    public function store(
        Request $request,
        FirebaseTokenVerifier $tokenVerifier,
        FirebaseUserSyncService $userSyncService
    ): JsonResponse {
        $payload = $request->validate([
            'service_slug' => [
                'required',
                'string',
                Rule::exists('service_types', 'slug')->where(
                    fn ($query) => $query->where('is_active', 1)
                ),
            ],
            'pickup_address' => ['required', 'string', 'max:255'],
            'destination_address' => ['required', 'string', 'max:255'],
            'payment_method' => ['required', Rule::in(['cash', 'wallet', 'card'])],
            'estimated_fare' => ['nullable', 'numeric', 'min:0'],
            'offered_fare' => ['nullable', 'numeric', 'min:0'],
            'city_id' => ['nullable', 'integer', Rule::exists('cities', 'id')],
            'scheduled_for' => ['nullable', 'date'],
            'notes' => ['nullable', 'string', 'max:2000'],
            'metadata' => ['nullable', 'array'],
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

        $serviceType = DB::table('service_types')
            ->where('slug', $payload['service_slug'])
            ->where('is_active', 1)
            ->first(['id', 'name', 'slug', 'category']);

        if ($serviceType === null) {
            return response()->json([
                'status' => 'error',
                'message' => 'The selected service is not available right now.',
            ], 422);
        }

        $scheduledFor = isset($payload['scheduled_for']) && trim((string) $payload['scheduled_for']) !== ''
            ? Carbon::parse((string) $payload['scheduled_for'])
            : null;

        $bookingStatus = $scheduledFor !== null && $scheduledFor->isFuture()
            ? 'scheduled'
            : 'pending';

        $priceType = isset($payload['offered_fare']) && (float) $payload['offered_fare'] > 0
            ? 'negotiated'
            : 'estimate';

        $estimatedFare = isset($payload['estimated_fare']) ? (float) $payload['estimated_fare'] : null;
        $offeredFare = isset($payload['offered_fare']) ? (float) $payload['offered_fare'] : null;

        $now = now();
        $bookingId = DB::table('bookings')->insertGetId([
            'booking_reference' => $this->generateBookingReference(),
            'service_type_id' => $serviceType->id,
            'city_id' => $payload['city_id'] ?? null,
            'rider_user_id' => $user->id,
            'booking_channel' => 'app',
            'booking_status' => $bookingStatus,
            'payment_status' => 'unpaid',
            'payment_method' => $payload['payment_method'],
            'price_type' => $priceType,
            'estimated_fare' => $estimatedFare,
            'offered_fare' => $offeredFare,
            'pickup_address' => trim((string) $payload['pickup_address']),
            'destination_address' => trim((string) $payload['destination_address']),
            'scheduled_for' => $scheduledFor?->toDateTimeString(),
            'requested_at' => $now->toDateTimeString(),
            'notes' => $payload['notes'] ?? null,
            'metadata' => json_encode(array_merge(
                $payload['metadata'] ?? [],
                [
                    'source' => 'mobile-app',
                    'service_slug' => $serviceType->slug,
                ]
            ), JSON_THROW_ON_ERROR),
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        DB::table('booking_status_history')->insert([
            'booking_id' => $bookingId,
            'old_status' => null,
            'new_status' => $bookingStatus,
            'changed_by_user_id' => $user->id,
            'note' => 'Created from mobile app.',
            'created_at' => $now,
        ]);

        $booking = $this->baseBookingQuery($user->id)
            ->where('b.id', $bookingId)
            ->first();

        return response()->json([
            'status' => 'ok',
            'message' => 'Booking created successfully.',
            'booking' => $booking ? $this->serializeBooking($booking) : null,
        ], 201);
    }

    public function updateStatus(
        Request $request,
        int $bookingId,
        FirebaseTokenVerifier $tokenVerifier,
        FirebaseUserSyncService $userSyncService
    ): JsonResponse {
        $payload = $request->validate([
            'status' => [
                'required',
                Rule::in([
                    'accepted',
                    'arriving',
                    'in_progress',
                    'completed',
                    'cancelled',
                ]),
            ],
            'note' => ['nullable', 'string', 'max:255'],
            'cancellation_reason' => ['nullable', 'string', 'max:255'],
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

        $booking = DB::transaction(function () use ($bookingId, $payload, $user) {
            $booking = DB::table('bookings as b')
                ->leftJoin('driver_profiles as dp', 'dp.id', '=', 'b.driver_profile_id')
                ->where('b.id', $bookingId)
                ->lockForUpdate()
                ->select([
                    'b.id',
                    'b.rider_user_id',
                    'b.driver_profile_id',
                    'b.booking_status',
                    'dp.user_id as driver_user_id',
                ])
                ->first();

            if ($booking === null) {
                abort(response()->json([
                    'status' => 'error',
                    'message' => 'Booking not found.',
                ], 404));
            }

            $requestedStatus = (string) $payload['status'];
            $currentStatus = (string) $booking->booking_status;
            $isRider = (int) $booking->rider_user_id === (int) $user->id;
            $isAssignedDriver = $booking->driver_user_id !== null && (int) $booking->driver_user_id === (int) $user->id;

            if (! $isRider && ! $isAssignedDriver) {
                abort(response()->json([
                    'status' => 'error',
                    'message' => 'You are not allowed to update this booking.',
                ], 403));
            }

            if ($isRider) {
                if ($requestedStatus !== 'cancelled') {
                    abort(response()->json([
                        'status' => 'error',
                        'message' => 'Riders can only cancel their booking from the app right now.',
                    ], 422));
                }

                if (! in_array($currentStatus, ['pending', 'searching', 'offered', 'accepted', 'scheduled'], true)) {
                    abort(response()->json([
                        'status' => 'error',
                        'message' => 'This booking can no longer be cancelled from the app.',
                    ], 422));
                }
            }

            if ($isAssignedDriver) {
                $allowedTransitions = [
                    'accepted' => ['accepted', 'arriving', 'cancelled'],
                    'arriving' => ['in_progress', 'cancelled'],
                    'in_progress' => ['completed', 'cancelled'],
                ];

                if (! isset($allowedTransitions[$currentStatus]) || ! in_array($requestedStatus, $allowedTransitions[$currentStatus], true)) {
                    abort(response()->json([
                        'status' => 'error',
                        'message' => 'That driver status transition is not available right now.',
                    ], 422));
                }
            }

            $timestampFields = [
                'updated_at' => now(),
            ];

            if ($requestedStatus === 'accepted' && $currentStatus !== 'accepted') {
                $timestampFields['accepted_at'] = now();
            }
            if ($requestedStatus === 'arriving') {
                $timestampFields['driver_arrived_at'] = now();
            }
            if ($requestedStatus === 'in_progress') {
                $timestampFields['started_at'] = now();
            }
            if ($requestedStatus === 'completed') {
                $timestampFields['completed_at'] = now();
            }
            if ($requestedStatus === 'cancelled') {
                $timestampFields['cancelled_at'] = now();
                $timestampFields['cancellation_reason'] = $payload['cancellation_reason'] ?? $payload['note'] ?? 'Cancelled from app';
            }

            DB::table('bookings')
                ->where('id', $bookingId)
                ->update(array_merge($timestampFields, [
                    'booking_status' => $requestedStatus,
                ]));

            if ($booking->driver_profile_id !== null && in_array($requestedStatus, ['completed', 'cancelled'], true)) {
                DB::table('driver_profiles')
                    ->where('id', $booking->driver_profile_id)
                    ->update([
                        'is_busy' => 0,
                        'updated_at' => now(),
                    ]);
            }

            DB::table('booking_status_history')->insert([
                'booking_id' => $bookingId,
                'old_status' => $currentStatus,
                'new_status' => $requestedStatus,
                'changed_by_user_id' => $user->id,
                'note' => $payload['note'] ?? ('Status updated from mobile app to ' . Str::headline(str_replace('_', ' ', $requestedStatus)) . '.'),
                'created_at' => now(),
            ]);

            return $this->baseBookingQuery($booking->rider_user_id)
                ->where('b.id', $bookingId)
                ->first();
        });

        return response()->json([
            'status' => 'ok',
            'message' => 'Booking status updated successfully.',
            'booking' => $booking ? $this->serializeBooking($booking) : null,
        ]);
    }

    public function storeTrackingPoint(
        Request $request,
        int $bookingId,
        FirebaseTokenVerifier $tokenVerifier,
        FirebaseUserSyncService $userSyncService
    ): JsonResponse {
        $payload = $request->validate([
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            'heading' => ['nullable', 'numeric', 'between:0,360'],
            'speed_kmh' => ['nullable', 'numeric', 'min:0'],
            'recorded_at' => ['nullable', 'date'],
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

        $driverProfile = DB::table('driver_profiles')
            ->where('user_id', $user->id)
            ->first(['id', 'status', 'onboarding_status']);

        if ($driverProfile === null || $driverProfile->status !== 'active' || $driverProfile->onboarding_status !== 'approved') {
            return response()->json([
                'status' => 'error',
                'message' => 'Only approved drivers can submit live tracking points.',
            ], 403);
        }

        $booking = DB::table('bookings')
            ->where('id', $bookingId)
            ->where('driver_profile_id', $driverProfile->id)
            ->first(['id', 'booking_status']);

        if ($booking === null) {
            return response()->json([
                'status' => 'error',
                'message' => 'This booking is not assigned to your driver account.',
            ], 404);
        }

        if (! in_array((string) $booking->booking_status, ['accepted', 'arriving', 'in_progress'], true)) {
            return response()->json([
                'status' => 'error',
                'message' => 'Tracking can only be sent for active assigned trips.',
            ], 422);
        }

        DB::table('ride_tracking_points')->insert([
            'booking_id' => $bookingId,
            'driver_profile_id' => $driverProfile->id,
            'latitude' => (float) $payload['latitude'],
            'longitude' => (float) $payload['longitude'],
            'heading' => isset($payload['heading']) ? (float) $payload['heading'] : null,
            'speed_kmh' => isset($payload['speed_kmh']) ? (float) $payload['speed_kmh'] : null,
            'recorded_at' => isset($payload['recorded_at'])
                ? Carbon::parse((string) $payload['recorded_at'])->toDateTimeString()
                : now()->toDateTimeString(),
            'created_at' => now(),
        ]);

        return response()->json([
            'status' => 'ok',
            'message' => 'Tracking point saved.',
        ], 201);
    }

    private function baseBookingQuery(int $userId)
    {
        return DB::table('bookings as b')
            ->join('service_types as st', 'st.id', '=', 'b.service_type_id')
            ->leftJoin('cities as c', 'c.id', '=', 'b.city_id')
            ->leftJoin('driver_profiles as dp', 'dp.id', '=', 'b.driver_profile_id')
            ->leftJoin('users as du', 'du.id', '=', 'dp.user_id')
            ->leftJoin('vehicles as v', 'v.id', '=', 'b.vehicle_id')
            ->leftJoin('vehicle_types as vt', 'vt.id', '=', 'v.vehicle_type_id')
            ->leftJoin('vehicle_makes as vmk', 'vmk.id', '=', 'v.vehicle_make_id')
            ->leftJoin('vehicle_models as vmd', 'vmd.id', '=', 'v.vehicle_model_id')
            ->where('b.rider_user_id', $userId)
            ->select([
                'b.id',
                'b.booking_reference',
                'b.booking_status',
                'b.payment_method',
                'b.price_type',
                'b.estimated_fare',
                'b.offered_fare',
                'b.final_fare',
                'b.pickup_address',
                'b.destination_address',
                'b.scheduled_for',
                'b.requested_at',
                'b.notes',
                'st.name as service_name',
                'st.slug as service_slug',
                'c.name as city_name',
                'du.full_name as driver_name',
                'du.phone as driver_phone',
                'dp.rating_average as driver_rating_average',
                'v.plate_number as driver_plate_number',
                'vt.name as vehicle_type_name',
                'vmk.name as vehicle_make_name',
                'vmd.name as vehicle_model_name',
            ]);
    }

    /**
     * @return array<string, mixed>
     */
    private function serializeBooking(object $booking): array
    {
        $scheduledFor = isset($booking->scheduled_for) && $booking->scheduled_for !== null
            ? Carbon::parse((string) $booking->scheduled_for)
            : null;

        return [
            'id' => (int) $booking->id,
            'reference' => (string) $booking->booking_reference,
            'service' => [
                'name' => (string) $booking->service_name,
                'slug' => (string) $booking->service_slug,
            ],
            'city_name' => $booking->city_name,
            'status' => (string) $booking->booking_status,
            'status_label' => $this->humanizeStatus((string) $booking->booking_status),
            'status_line' => $this->buildStatusLine((string) $booking->booking_status, $scheduledFor),
            'pickup_address' => (string) $booking->pickup_address,
            'destination_address' => (string) $booking->destination_address,
            'route_line' => trim((string) $booking->pickup_address) . ' -> ' . trim((string) $booking->destination_address),
            'payment_method' => (string) $booking->payment_method,
            'payment_label' => Str::headline((string) $booking->payment_method) . ' payment',
            'fare_label' => $this->formatFareLabel($booking),
            'requested_at' => $booking->requested_at,
            'scheduled_for' => $scheduledFor?->toIso8601String(),
            'notes' => $booking->notes,
            'driver' => $this->serializeDriver($booking),
        ];
    }

    private function buildStatusLine(string $status, ?Carbon $scheduledFor): string
    {
        return match ($status) {
            'scheduled' => $scheduledFor !== null
                ? 'Scheduled for ' . $scheduledFor->format('D, j M g:i A')
                : 'Scheduled trip created',
            'pending' => 'Booking received and awaiting dispatch',
            'searching' => 'Looking for a nearby driver',
            'offered' => 'A driver offer is waiting for your response',
            'accepted' => 'Driver accepted and preparing for pickup',
            'arriving' => 'Driver is on the way to your pickup',
            'in_progress' => 'Trip is currently in progress',
            'completed' => 'Trip completed successfully',
            'cancelled' => 'Booking was cancelled',
            default => $this->humanizeStatus($status),
        };
    }

    private function formatFareLabel(object $booking): string
    {
        $amount = $booking->final_fare
            ?? $booking->offered_fare
            ?? $booking->estimated_fare;

        if ($amount === null) {
            return 'Fare to confirm';
        }

        return 'PKR ' . number_format((float) $amount, 0);
    }

    private function generateBookingReference(): string
    {
        do {
            $reference = 'OWR-' . now()->format('ymd') . '-' . Str::upper(Str::random(6));
        } while (DB::table('bookings')->where('booking_reference', $reference)->exists());

        return $reference;
    }

    private function humanizeStatus(string $status): string
    {
        return Str::headline(str_replace('_', ' ', $status));
    }

    /**
     * @return array<string, mixed>|null
     */
    private function serializeDriver(object $booking): ?array
    {
        if (! isset($booking->driver_name) || trim((string) $booking->driver_name) === '') {
            return null;
        }

        $vehicleLabel = collect([
            $booking->vehicle_make_name ?? null,
            $booking->vehicle_model_name ?? null,
            $booking->vehicle_type_name ?? null,
        ])
            ->filter(fn ($value): bool => $value !== null && trim((string) $value) !== '')
            ->implode(' ');

        return [
            'name' => (string) $booking->driver_name,
            'rating' => number_format((float) ($booking->driver_rating_average ?? 5), 1),
            'vehicle' => $vehicleLabel !== '' ? $vehicleLabel : 'Vehicle assigned',
            'plate' => $booking->driver_plate_number ?? 'Plate pending',
            'phone' => $booking->driver_phone ?? 'Phone pending',
            'distance_away' => 'Live location updating',
            'eta' => match ((string) $booking->booking_status) {
                'accepted' => 'Preparing for pickup',
                'arriving' => 'Driver is arriving',
                'in_progress' => 'Trip in progress',
                default => 'Driver assigned',
            },
        ];
    }
}
