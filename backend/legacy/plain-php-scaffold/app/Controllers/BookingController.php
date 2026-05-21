<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Support\BookingCalculator;
use App\Support\Database;
use App\Support\Request;
use PDO;
use RuntimeException;

final class BookingController
{
    /**
     * @param array<string, string> $params
     * @return array{status:int,data:array<string,mixed>}
     */
    public function estimate(Request $request, array $params = []): array
    {
        $cityId = (int) $request->input('city_id', 0);
        $serviceTypeId = (int) $request->input('service_type_id', 0);
        $vehicleTypeId = $request->input('vehicle_type_id');
        $distanceKm = (float) $request->input('distance_km', 0);
        $durationMinutes = (int) $request->input('duration_minutes', 0);

        if ($cityId <= 0 || $serviceTypeId <= 0) {
            return [
                'status' => 422,
                'data' => [
                    'success' => false,
                    'message' => 'city_id and service_type_id are required.',
                ],
            ];
        }

        $pricing = $this->findPricingRule($cityId, $serviceTypeId, is_numeric((string) $vehicleTypeId) ? (int) $vehicleTypeId : null);
        if ($pricing === null) {
            return [
                'status' => 404,
                'data' => [
                    'success' => false,
                    'message' => 'No pricing rule found for this service and city.',
                ],
            ];
        }

        $estimate = BookingCalculator::estimate($pricing, $distanceKm, $durationMinutes);

        return [
            'status' => 200,
            'data' => [
                'success' => true,
                'data' => [
                    'service' => [
                        'id' => (int) $pricing['service_type_id'],
                        'name' => $pricing['service_name'],
                        'slug' => $pricing['service_slug'],
                        'supports_negotiation' => (bool) $pricing['supports_negotiation'],
                        'supports_scheduling' => (bool) $pricing['supports_scheduling'],
                    ],
                    'pricing' => $estimate,
                ],
            ],
        ];
    }

    /**
     * @param array<string, string> $params
     * @return array{status:int,data:array<string,mixed>}
     */
    public function create(Request $request, array $params = []): array
    {
        $riderUserId = (int) $request->input('rider_user_id', 0);
        $serviceTypeId = (int) $request->input('service_type_id', 0);
        $cityId = (int) $request->input('city_id', 0);

        if ($riderUserId <= 0 || $serviceTypeId <= 0 || $cityId <= 0) {
            return [
                'status' => 422,
                'data' => [
                    'success' => false,
                    'message' => 'rider_user_id, service_type_id, and city_id are required.',
                ],
            ];
        }

        $pdo = Database::connection();
        $pdo->beginTransaction();

        try {
            $service = $this->serviceById($pdo, $serviceTypeId);
            if ($service === null) {
                throw new RuntimeException('Service not found.');
            }

            $bookingReference = $this->generateBookingReference();
            $priceType = (string) $request->input('price_type', 'estimate');
            $estimatedFare = $request->input('estimated_fare');
            $offeredFare = $request->input('offered_fare');
            $scheduledFor = $request->input('scheduled_for');
            $bookingStatus = $scheduledFor ? 'scheduled' : 'pending';

            $insert = $pdo->prepare(
                "INSERT INTO bookings
                (booking_reference, service_type_id, city_id, rider_user_id, booking_channel, booking_status, payment_status, payment_method, price_type,
                 estimated_fare, offered_fare, final_fare, distance_km, duration_minutes, pickup_address, pickup_latitude, pickup_longitude,
                 destination_address, destination_latitude, destination_longitude, scheduled_for, notes, metadata)
                VALUES
                (:booking_reference, :service_type_id, :city_id, :rider_user_id, 'app', :booking_status, 'unpaid', :payment_method, :price_type,
                 :estimated_fare, :offered_fare, :final_fare, :distance_km, :duration_minutes, :pickup_address, :pickup_latitude, :pickup_longitude,
                 :destination_address, :destination_latitude, :destination_longitude, :scheduled_for, :notes, :metadata)"
            );

            $insert->execute([
                'booking_reference' => $bookingReference,
                'service_type_id' => $serviceTypeId,
                'city_id' => $cityId,
                'rider_user_id' => $riderUserId,
                'booking_status' => $bookingStatus,
                'payment_method' => (string) $request->input('payment_method', 'cash'),
                'price_type' => $priceType,
                'estimated_fare' => $estimatedFare !== null ? (float) $estimatedFare : null,
                'offered_fare' => $offeredFare !== null ? (float) $offeredFare : null,
                'final_fare' => $estimatedFare !== null ? (float) $estimatedFare : null,
                'distance_km' => (float) $request->input('distance_km', 0),
                'duration_minutes' => (int) $request->input('duration_minutes', 0),
                'pickup_address' => $request->input('pickup_address'),
                'pickup_latitude' => $request->input('pickup_latitude'),
                'pickup_longitude' => $request->input('pickup_longitude'),
                'destination_address' => $request->input('destination_address'),
                'destination_latitude' => $request->input('destination_latitude'),
                'destination_longitude' => $request->input('destination_longitude'),
                'scheduled_for' => $scheduledFor ?: null,
                'notes' => $request->input('notes'),
                'metadata' => json_encode($request->body(), JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE),
            ]);

            $bookingId = (int) $pdo->lastInsertId();
            $this->insertStatusHistory($pdo, $bookingId, null, $bookingStatus, $riderUserId, 'Booking created');

            if ($priceType === 'negotiated' && $offeredFare !== null) {
                $offer = $pdo->prepare(
                    "INSERT INTO booking_offers
                     (booking_id, offered_by_user_id, offer_source, amount, status, note, expires_at)
                     VALUES
                     (:booking_id, :offered_by_user_id, 'rider', :amount, 'pending', :note, DATE_ADD(NOW(), INTERVAL 90 SECOND))"
                );
                $offer->execute([
                    'booking_id' => $bookingId,
                    'offered_by_user_id' => $riderUserId,
                    'amount' => (float) $offeredFare,
                    'note' => 'Rider offered fare during booking creation.',
                ]);
            }

            $this->insertServiceSpecificRecord($pdo, $bookingId, $service['category'], $request);

            $pdo->commit();

            return [
                'status' => 201,
                'data' => [
                    'success' => true,
                    'message' => 'Booking created successfully.',
                    'data' => [
                        'booking_id' => $bookingId,
                        'booking_reference' => $bookingReference,
                        'booking_status' => $bookingStatus,
                        'todo' => 'Dispatching and live driver assignment should be connected next.',
                    ],
                ],
            ];
        } catch (\Throwable $exception) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }

            throw $exception;
        }
    }

    /**
     * @param array<string, string> $params
     * @return array{status:int,data:array<string,mixed>}
     */
    public function show(Request $request, array $params = []): array
    {
        $reference = $params['reference'] ?? '';
        $pdo = Database::connection();

        $statement = $pdo->prepare(
            "SELECT
                b.*,
                st.name AS service_name,
                st.slug AS service_slug,
                rider.full_name AS rider_name,
                driver_user.full_name AS driver_name
             FROM bookings b
             INNER JOIN service_types st ON st.id = b.service_type_id
             INNER JOIN users rider ON rider.id = b.rider_user_id
             LEFT JOIN driver_profiles dp ON dp.id = b.driver_profile_id
             LEFT JOIN users driver_user ON driver_user.id = dp.user_id
             WHERE b.booking_reference = :booking_reference
             LIMIT 1"
        );
        $statement->execute(['booking_reference' => $reference]);

        $booking = $statement->fetch();
        if ($booking === false) {
            return [
                'status' => 404,
                'data' => [
                    'success' => false,
                    'message' => 'Booking not found.',
                ],
            ];
        }

        return [
            'status' => 200,
            'data' => [
                'success' => true,
                'data' => [
                    'booking' => $booking,
                ],
            ],
        ];
    }

    private function findPricingRule(int $cityId, int $serviceTypeId, ?int $vehicleTypeId): ?array
    {
        $pdo = Database::connection();
        $statement = $pdo->prepare(
            "SELECT
                pr.*,
                st.name AS service_name,
                st.slug AS service_slug,
                css.supports_negotiation,
                css.supports_scheduling
             FROM pricing_rules pr
             INNER JOIN service_types st ON st.id = pr.service_type_id
             LEFT JOIN city_service_settings css
                ON css.city_id = pr.city_id
               AND css.service_type_id = pr.service_type_id
             WHERE pr.city_id = :city_id
               AND pr.service_type_id = :service_type_id
               AND pr.is_active = 1
               AND (pr.vehicle_type_id = :vehicle_type_id OR pr.vehicle_type_id IS NULL)
             ORDER BY pr.vehicle_type_id IS NULL, pr.id DESC
             LIMIT 1"
        );
        $statement->execute([
            'city_id' => $cityId,
            'service_type_id' => $serviceTypeId,
            'vehicle_type_id' => $vehicleTypeId,
        ]);

        $pricing = $statement->fetch();
        return $pricing === false ? null : $pricing;
    }

    /**
     * @return array<string, mixed>|null
     */
    private function serviceById(PDO $pdo, int $serviceTypeId): ?array
    {
        $statement = $pdo->prepare("SELECT id, name, slug, category FROM service_types WHERE id = :id LIMIT 1");
        $statement->execute(['id' => $serviceTypeId]);
        $service = $statement->fetch();
        return $service === false ? null : $service;
    }

    private function insertStatusHistory(PDO $pdo, int $bookingId, ?string $oldStatus, string $newStatus, ?int $changedByUserId, string $note): void
    {
        $statement = $pdo->prepare(
            "INSERT INTO booking_status_history (booking_id, old_status, new_status, changed_by_user_id, note)
             VALUES (:booking_id, :old_status, :new_status, :changed_by_user_id, :note)"
        );
        $statement->execute([
            'booking_id' => $bookingId,
            'old_status' => $oldStatus,
            'new_status' => $newStatus,
            'changed_by_user_id' => $changedByUserId,
            'note' => $note,
        ]);
    }

    private function insertServiceSpecificRecord(PDO $pdo, int $bookingId, string $category, Request $request): void
    {
        switch ($category) {
            case 'rental':
                $statement = $pdo->prepare(
                    "INSERT INTO rental_bookings (booking_id, rental_type, start_at, end_at, with_driver, included_km, extra_km_rate)
                     VALUES (:booking_id, :rental_type, :start_at, :end_at, :with_driver, :included_km, :extra_km_rate)"
                );
                $statement->execute([
                    'booking_id' => $bookingId,
                    'rental_type' => (string) $request->input('rental_type', 'hourly'),
                    'start_at' => $request->input('start_at') ?: date('Y-m-d H:i:s'),
                    'end_at' => $request->input('end_at') ?: date('Y-m-d H:i:s', strtotime('+1 hour')),
                    'with_driver' => $request->input('with_driver', true) ? 1 : 0,
                    'included_km' => $request->input('included_km'),
                    'extra_km_rate' => $request->input('extra_km_rate'),
                ]);
                break;

            case 'school':
                $statement = $pdo->prepare(
                    "INSERT INTO school_bookings
                     (booking_id, institution_name, passenger_name, pickup_days, dropoff_days, guardian_name, guardian_phone, monthly_fee)
                     VALUES
                     (:booking_id, :institution_name, :passenger_name, :pickup_days, :dropoff_days, :guardian_name, :guardian_phone, :monthly_fee)"
                );
                $statement->execute([
                    'booking_id' => $bookingId,
                    'institution_name' => (string) $request->input('institution_name', 'School transport'),
                    'passenger_name' => (string) $request->input('passenger_name', 'Passenger'),
                    'pickup_days' => $request->input('pickup_days'),
                    'dropoff_days' => $request->input('dropoff_days'),
                    'guardian_name' => $request->input('guardian_name'),
                    'guardian_phone' => $request->input('guardian_phone'),
                    'monthly_fee' => $request->input('monthly_fee'),
                ]);
                break;

            case 'food':
                $statement = $pdo->prepare(
                    "INSERT INTO food_orders
                     (booking_id, food_merchant_id, subtotal, delivery_fee, packaging_fee, tax_amount, special_instructions)
                     VALUES
                     (:booking_id, :food_merchant_id, :subtotal, :delivery_fee, :packaging_fee, :tax_amount, :special_instructions)"
                );
                $statement->execute([
                    'booking_id' => $bookingId,
                    'food_merchant_id' => (int) $request->input('food_merchant_id', 0),
                    'subtotal' => (float) $request->input('subtotal', 0),
                    'delivery_fee' => (float) $request->input('delivery_fee', 0),
                    'packaging_fee' => (float) $request->input('packaging_fee', 0),
                    'tax_amount' => (float) $request->input('tax_amount', 0),
                    'special_instructions' => $request->input('special_instructions'),
                ]);
                break;

            case 'delivery':
                $statement = $pdo->prepare(
                    "INSERT INTO courier_orders
                     (booking_id, receiver_name, receiver_phone, parcel_type, item_description, fragile, weight_kg, declared_value, pickup_contact_name, pickup_contact_phone)
                     VALUES
                     (:booking_id, :receiver_name, :receiver_phone, :parcel_type, :item_description, :fragile, :weight_kg, :declared_value, :pickup_contact_name, :pickup_contact_phone)"
                );
                $statement->execute([
                    'booking_id' => $bookingId,
                    'receiver_name' => (string) $request->input('receiver_name', 'Receiver'),
                    'receiver_phone' => (string) $request->input('receiver_phone', ''),
                    'parcel_type' => $request->input('parcel_type'),
                    'item_description' => $request->input('item_description'),
                    'fragile' => $request->input('fragile', false) ? 1 : 0,
                    'weight_kg' => $request->input('weight_kg'),
                    'declared_value' => $request->input('declared_value'),
                    'pickup_contact_name' => $request->input('pickup_contact_name'),
                    'pickup_contact_phone' => $request->input('pickup_contact_phone'),
                ]);
                break;

            default:
                $statement = $pdo->prepare(
                    "INSERT INTO ride_bookings
                     (booking_id, ride_class, dispatch_mode, seats_required, luggage_required, special_instructions, estimated_distance_km, estimated_duration_minutes, airport_terminal, is_round_trip)
                     VALUES
                     (:booking_id, :ride_class, :dispatch_mode, :seats_required, :luggage_required, :special_instructions, :estimated_distance_km, :estimated_duration_minutes, :airport_terminal, :is_round_trip)"
                );
                $statement->execute([
                    'booking_id' => $bookingId,
                    'ride_class' => $request->input('ride_class'),
                    'dispatch_mode' => (string) $request->input('dispatch_mode', 'automatic'),
                    'seats_required' => $request->input('seats_required'),
                    'luggage_required' => $request->input('luggage_required'),
                    'special_instructions' => $request->input('special_instructions'),
                    'estimated_distance_km' => (float) $request->input('distance_km', 0),
                    'estimated_duration_minutes' => (int) $request->input('duration_minutes', 0),
                    'airport_terminal' => $request->input('airport_terminal'),
                    'is_round_trip' => $request->input('is_round_trip', false) ? 1 : 0,
                ]);
                break;
        }
    }

    private function generateBookingReference(): string
    {
        return 'ONW-' . date('Ymd') . '-' . strtoupper(bin2hex(random_bytes(3)));
    }
}
