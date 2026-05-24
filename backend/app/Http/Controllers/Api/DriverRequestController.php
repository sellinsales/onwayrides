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
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class DriverRequestController extends Controller
{
    use ResolvesFirebaseRequestUser;

    public function index(
        Request $request,
        FirebaseTokenVerifier $tokenVerifier,
        FirebaseUserSyncService $userSyncService
    ): JsonResponse {
        try {
            [$user, $driverProfile] = $this->resolveApprovedDriver($request, $tokenVerifier, $userSyncService);
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

        $enabledServiceIds = DB::table('driver_service_enablements')
            ->where('driver_profile_id', $driverProfile->id)
            ->where('is_enabled', 1)
            ->pluck('service_type_id')
            ->map(fn ($id): int => (int) $id)
            ->all();

        $currentBooking = $this->currentBookingQuery((int) $driverProfile->id)->first();

        $requests = $enabledServiceIds === []
            ? collect()
            : $this->availableRequestsQuery((int) $driverProfile->id, (int) $driverProfile->city_id, $enabledServiceIds)
                ->orderByDesc('b.requested_at')
                ->limit(15)
                ->get();

        return response()->json([
            'status' => 'ok',
            'driver_mode' => [
                'is_online' => (bool) $driverProfile->is_online,
                'is_busy' => (bool) $driverProfile->is_busy,
            ],
            'current_booking' => $currentBooking ? $this->serializeCurrentBooking($currentBooking) : null,
            'requests' => $requests->map(fn (object $booking): array => $this->serializeRequest($booking))->all(),
        ]);
    }

    public function accept(
        Request $request,
        int $bookingId,
        FirebaseTokenVerifier $tokenVerifier,
        FirebaseUserSyncService $userSyncService
    ): JsonResponse {
        try {
            [$user, $driverProfile] = $this->resolveApprovedDriver($request, $tokenVerifier, $userSyncService);
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

        $now = now();

        $result = DB::transaction(function () use ($bookingId, $driverProfile, $user, $now) {
            $booking = $this->lockBookingForDriver($bookingId, $driverProfile);
            $currentStatus = (string) $booking->booking_status;
            $pendingOffer = $this->pendingOfferForDriver($bookingId, (int) $driverProfile->id);

            if ($currentStatus === 'offered' && $pendingOffer === null) {
                throw ValidationException::withMessages([
                    'booking' => 'This request already has a driver counter-offer in progress.',
                ]);
            }

            $amount = $pendingOffer?->amount
                ?? $booking->counter_fare
                ?? $booking->offered_fare
                ?? $booking->estimated_fare;

            $vehicleId = $this->resolveDriverVehicleId((int) $driverProfile->id, (int) $user->id);

            DB::table('bookings')
                ->where('id', $bookingId)
                ->update([
                    'driver_profile_id' => $driverProfile->id,
                    'vehicle_id' => $vehicleId,
                    'booking_status' => 'accepted',
                    'accepted_at' => $now,
                    'offered_fare' => $amount,
                    'updated_at' => $now,
                ]);

            DB::table('driver_profiles')
                ->where('id', $driverProfile->id)
                ->update([
                    'is_busy' => 1,
                    'updated_at' => $now,
                ]);

            DB::table('booking_offers')
                ->where('booking_id', $bookingId)
                ->where('status', 'pending')
                ->update([
                    'status' => 'expired',
                    'responded_at' => $now,
                    'updated_at' => $now,
                ]);

            if ($pendingOffer !== null) {
                DB::table('booking_offers')
                    ->where('id', $pendingOffer->id)
                    ->update([
                        'status' => 'accepted',
                        'responded_at' => $now,
                        'updated_at' => $now,
                    ]);
            } else {
                DB::table('booking_offers')->insert([
                    'booking_id' => $bookingId,
                    'driver_profile_id' => $driverProfile->id,
                    'offered_by_user_id' => $user->id,
                    'offer_source' => 'driver',
                    'amount' => $amount ?? 0,
                    'note' => 'Accepted directly from mobile driver queue.',
                    'status' => 'accepted',
                    'responded_at' => $now,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }

            DB::table('booking_status_history')->insert([
                'booking_id' => $bookingId,
                'old_status' => $currentStatus,
                'new_status' => 'accepted',
                'changed_by_user_id' => $user->id,
                'note' => 'Driver accepted from mobile queue.',
                'created_at' => $now,
            ]);

            return $this->currentBookingQuery((int) $driverProfile->id)
                ->where('b.id', $bookingId)
                ->first();
        });

        return response()->json([
            'status' => 'ok',
            'message' => 'Request accepted successfully.',
            'current_booking' => $result ? $this->serializeCurrentBooking($result) : null,
        ]);
    }

    public function reject(
        Request $request,
        int $bookingId,
        FirebaseTokenVerifier $tokenVerifier,
        FirebaseUserSyncService $userSyncService
    ): JsonResponse {
        try {
            [$user, $driverProfile] = $this->resolveApprovedDriver($request, $tokenVerifier, $userSyncService);
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

        $now = now();

        DB::transaction(function () use ($bookingId, $driverProfile, $user, $now) {
            $booking = $this->lockBookingForDriver($bookingId, $driverProfile);
            $currentStatus = (string) $booking->booking_status;
            $pendingOffer = $this->pendingOfferForDriver($bookingId, (int) $driverProfile->id);

            if ($pendingOffer !== null) {
                DB::table('booking_offers')
                    ->where('id', $pendingOffer->id)
                    ->update([
                        'status' => 'rejected',
                        'responded_at' => $now,
                        'updated_at' => $now,
                    ]);

                DB::table('bookings')
                    ->where('id', $bookingId)
                    ->update([
                        'booking_status' => 'searching',
                        'updated_at' => $now,
                    ]);

                DB::table('booking_status_history')->insert([
                    'booking_id' => $bookingId,
                    'old_status' => $currentStatus,
                    'new_status' => 'searching',
                    'changed_by_user_id' => $user->id,
                    'note' => 'Driver rejected a pending counter-offer.',
                    'created_at' => $now,
                ]);

                return;
            }

            DB::table('booking_offers')->insert([
                'booking_id' => $bookingId,
                'driver_profile_id' => $driverProfile->id,
                'offered_by_user_id' => $user->id,
                'offer_source' => 'driver',
                'amount' => $booking->counter_fare ?? $booking->offered_fare ?? $booking->estimated_fare ?? 0,
                'note' => 'Rejected from mobile driver queue.',
                'status' => 'rejected',
                'responded_at' => $now,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        });

        return response()->json([
            'status' => 'ok',
            'message' => 'Request rejected.',
        ]);
    }

    public function counterOffer(
        Request $request,
        int $bookingId,
        FirebaseTokenVerifier $tokenVerifier,
        FirebaseUserSyncService $userSyncService
    ): JsonResponse {
        $payload = $request->validate([
            'amount' => ['required', 'numeric', 'min:1'],
            'note' => ['nullable', 'string', 'max:255'],
        ]);

        try {
            [$user, $driverProfile] = $this->resolveApprovedDriver($request, $tokenVerifier, $userSyncService);
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

        $now = now();

        DB::transaction(function () use ($bookingId, $driverProfile, $user, $payload, $now) {
            $booking = $this->lockBookingForDriver($bookingId, $driverProfile);
            $currentStatus = (string) $booking->booking_status;

            if ($currentStatus === 'offered') {
                $pendingOffer = $this->pendingOfferForDriver($bookingId, (int) $driverProfile->id);
                if ($pendingOffer === null) {
                    throw ValidationException::withMessages([
                        'booking' => 'Another counter-offer is already in progress for this booking.',
                    ]);
                }

                DB::table('booking_offers')
                    ->where('id', $pendingOffer->id)
                    ->update([
                        'amount' => (float) $payload['amount'],
                        'note' => $payload['note'] ?? 'Driver counter-offer updated from mobile.',
                        'expires_at' => $now->copy()->addMinutes(8),
                        'updated_at' => $now,
                    ]);
            } else {
                DB::table('booking_offers')->insert([
                    'booking_id' => $bookingId,
                    'driver_profile_id' => $driverProfile->id,
                    'offered_by_user_id' => $user->id,
                    'offer_source' => 'driver',
                    'amount' => (float) $payload['amount'],
                    'note' => $payload['note'] ?? 'Driver counter-offer sent from mobile queue.',
                    'status' => 'pending',
                    'expires_at' => $now->copy()->addMinutes(8),
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }

            DB::table('bookings')
                ->where('id', $bookingId)
                ->update([
                    'booking_status' => 'offered',
                    'counter_fare' => (float) $payload['amount'],
                    'updated_at' => $now,
                ]);

            DB::table('booking_status_history')->insert([
                'booking_id' => $bookingId,
                'old_status' => $currentStatus,
                'new_status' => 'offered',
                'changed_by_user_id' => $user->id,
                'note' => $payload['note'] ?? 'Driver counter-offer sent from mobile queue.',
                'created_at' => $now,
            ]);
        });

        return response()->json([
            'status' => 'ok',
            'message' => 'Counter-offer sent.',
        ]);
    }

    /**
     * @return array{0: object, 1: object}
     */
    private function resolveApprovedDriver(
        Request $request,
        FirebaseTokenVerifier $tokenVerifier,
        FirebaseUserSyncService $userSyncService
    ): array {
        $user = $this->resolveAuthenticatedUser($request, $tokenVerifier, $userSyncService);
        $driverProfile = DB::table('driver_profiles')
            ->where('user_id', $user->id)
            ->first();

        if ($driverProfile === null) {
            throw ValidationException::withMessages([
                'driver' => 'Start and submit your driver application first.',
            ]);
        }

        if ($driverProfile->status !== 'active' || $driverProfile->onboarding_status !== 'approved') {
            throw ValidationException::withMessages([
                'driver' => 'Driver dispatch becomes available after approval.',
            ]);
        }

        return [$user, $driverProfile];
    }

    private function availableRequestsQuery(int $driverProfileId, int $cityId, array $enabledServiceIds)
    {
        return DB::table('bookings as b')
            ->join('service_types as st', 'st.id', '=', 'b.service_type_id')
            ->join('users as rider', 'rider.id', '=', 'b.rider_user_id')
            ->leftJoin('cities as c', 'c.id', '=', 'b.city_id')
            ->whereNull('b.driver_profile_id')
            ->whereIn('b.service_type_id', $enabledServiceIds)
            ->where(function ($query) use ($cityId) {
                $query
                    ->whereNull('b.city_id')
                    ->orWhere('b.city_id', $cityId);
            })
            ->where(function ($query) use ($driverProfileId) {
                $query
                    ->where(function ($query) use ($driverProfileId) {
                        $query
                            ->whereIn('b.booking_status', ['pending', 'searching', 'scheduled'])
                            ->whereNotExists(function ($subQuery) use ($driverProfileId) {
                                $subQuery
                                    ->select(DB::raw(1))
                                    ->from('booking_offers as bo')
                                    ->whereColumn('bo.booking_id', 'b.id')
                                    ->where('bo.driver_profile_id', $driverProfileId)
                                    ->whereIn('bo.status', ['rejected', 'accepted', 'withdrawn']);
                            });
                    })
                    ->orWhere(function ($query) use ($driverProfileId) {
                        $query
                            ->where('b.booking_status', 'offered')
                            ->whereExists(function ($subQuery) use ($driverProfileId) {
                                $subQuery
                                    ->select(DB::raw(1))
                                    ->from('booking_offers as bo')
                                    ->whereColumn('bo.booking_id', 'b.id')
                                    ->where('bo.driver_profile_id', $driverProfileId)
                                    ->where('bo.status', 'pending');
                            });
                    });
            })
            ->select([
                'b.id',
                'b.booking_reference',
                'b.booking_status',
                'b.payment_method',
                'b.pickup_address',
                'b.destination_address',
                'b.estimated_fare',
                'b.offered_fare',
                'b.counter_fare',
                'b.requested_at',
                'st.name as service_name',
                'rider.full_name as rider_name',
                'c.name as city_name',
            ]);
    }

    private function currentBookingQuery(int $driverProfileId)
    {
        return DB::table('bookings as b')
            ->join('service_types as st', 'st.id', '=', 'b.service_type_id')
            ->join('users as rider', 'rider.id', '=', 'b.rider_user_id')
            ->where('b.driver_profile_id', $driverProfileId)
            ->whereIn('b.booking_status', ['accepted', 'arriving', 'in_progress'])
            ->orderByDesc('b.accepted_at')
            ->select([
                'b.id',
                'b.booking_reference',
                'b.booking_status',
                'b.payment_method',
                'b.pickup_address',
                'b.destination_address',
                'b.estimated_fare',
                'b.offered_fare',
                'b.counter_fare',
                'b.final_fare',
                'rider.full_name as rider_name',
                'rider.phone as rider_phone',
                'st.name as service_name',
            ]);
    }

    private function lockBookingForDriver(int $bookingId, object $driverProfile): object
    {
        $enabledServiceIds = DB::table('driver_service_enablements')
            ->where('driver_profile_id', $driverProfile->id)
            ->where('is_enabled', 1)
            ->pluck('service_type_id')
            ->map(fn ($id): int => (int) $id)
            ->all();

        $booking = DB::table('bookings')
            ->where('id', $bookingId)
            ->lockForUpdate()
            ->first();

        if ($booking === null) {
            throw ValidationException::withMessages([
                'booking' => 'The request could not be found.',
            ]);
        }

        if ($booking->driver_profile_id !== null && (int) $booking->driver_profile_id !== (int) $driverProfile->id) {
            throw ValidationException::withMessages([
                'booking' => 'This request was already assigned to another driver.',
            ]);
        }

        if ($booking->city_id !== null && (int) $booking->city_id !== (int) $driverProfile->city_id) {
            throw ValidationException::withMessages([
                'booking' => 'This request is outside your active city coverage.',
            ]);
        }

        if (! in_array((int) $booking->service_type_id, $enabledServiceIds, true)) {
            throw ValidationException::withMessages([
                'booking' => 'This request does not match your enabled driver services.',
            ]);
        }

        if (! in_array((string) $booking->booking_status, ['pending', 'searching', 'offered', 'scheduled'], true)) {
            throw ValidationException::withMessages([
                'booking' => 'This request is no longer available in the driver queue.',
            ]);
        }

        return $booking;
    }

    private function pendingOfferForDriver(int $bookingId, int $driverProfileId): ?object
    {
        return DB::table('booking_offers')
            ->where('booking_id', $bookingId)
            ->where('driver_profile_id', $driverProfileId)
            ->where('status', 'pending')
            ->latest('id')
            ->first();
    }

    private function resolveDriverVehicleId(int $driverProfileId, int $userId): ?int
    {
        $currentVehicleId = DB::table('driver_vehicle_assignments')
            ->where('driver_profile_id', $driverProfileId)
            ->where('is_current', 1)
            ->value('vehicle_id');

        if ($currentVehicleId !== null) {
            return (int) $currentVehicleId;
        }

        $fallbackVehicleId = DB::table('vehicles')
            ->where('registered_owner_user_id', $userId)
            ->orderByDesc('updated_at')
            ->value('id');

        return $fallbackVehicleId !== null ? (int) $fallbackVehicleId : null;
    }

    /**
     * @return array<string, mixed>
     */
    private function serializeRequest(object $booking): array
    {
        return [
            'id' => (int) $booking->id,
            'reference' => (string) $booking->booking_reference,
            'service_title' => (string) $booking->service_name,
            'rider_name' => (string) $booking->rider_name,
            'pickup' => (string) $booking->pickup_address,
            'dropoff' => (string) $booking->destination_address,
            'fare_label' => $this->formatFareLabel($booking),
            'distance_label' => $booking->city_name !== null
                ? 'City: ' . $booking->city_name
                : 'Nearby request',
            'payment_label' => Str::headline((string) $booking->payment_method),
            'status' => (string) $booking->booking_status,
            'status_line' => match ((string) $booking->booking_status) {
                'offered' => 'Your counter-offer is awaiting rider confirmation.',
                'scheduled' => 'Scheduled request available for pickup planning.',
                default => 'Request ready for driver action.',
            },
            'can_counter' => ! in_array((string) $booking->booking_status, ['scheduled'], true),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function serializeCurrentBooking(object $booking): array
    {
        return [
            'id' => (int) $booking->id,
            'reference' => (string) $booking->booking_reference,
            'service_title' => (string) $booking->service_name,
            'rider_name' => (string) $booking->rider_name,
            'rider_phone' => $booking->rider_phone,
            'pickup' => (string) $booking->pickup_address,
            'dropoff' => (string) $booking->destination_address,
            'status' => (string) $booking->booking_status,
            'status_label' => Str::headline(str_replace('_', ' ', (string) $booking->booking_status)),
            'fare_label' => $this->formatFareLabel($booking),
            'payment_label' => Str::headline((string) $booking->payment_method),
        ];
    }

    private function formatFareLabel(object $booking): string
    {
        $amount = $booking->final_fare
            ?? $booking->counter_fare
            ?? $booking->offered_fare
            ?? $booking->estimated_fare;

        if ($amount === null) {
            return 'Fare to confirm';
        }

        return 'PKR ' . number_format((float) $amount, 0);
    }
}
