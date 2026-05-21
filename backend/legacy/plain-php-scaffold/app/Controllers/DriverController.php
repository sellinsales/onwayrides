<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Support\Database;
use App\Support\Request;
use PDO;
use RuntimeException;

final class DriverController
{
    /**
     * @param array<string, string> $params
     * @return array{status:int,data:array<string,mixed>}
     */
    public function updateStatus(Request $request, array $params = []): array
    {
        $driverProfileId = (int) $request->input('driver_profile_id', 0);
        if ($driverProfileId <= 0) {
            return [
                'status' => 422,
                'data' => [
                    'success' => false,
                    'message' => 'driver_profile_id is required.',
                ],
            ];
        }

        $pdo = Database::connection();
        $statement = $pdo->prepare(
            "UPDATE driver_profiles
             SET is_online = :is_online,
                 is_busy = :is_busy,
                 last_latitude = :last_latitude,
                 last_longitude = :last_longitude,
                 last_location_at = CASE
                    WHEN :last_latitude IS NOT NULL AND :last_longitude IS NOT NULL THEN NOW()
                    ELSE last_location_at
                 END
             WHERE id = :id"
        );
        $statement->execute([
            'is_online' => $request->input('is_online', false) ? 1 : 0,
            'is_busy' => $request->input('is_busy', false) ? 1 : 0,
            'last_latitude' => $request->input('last_latitude'),
            'last_longitude' => $request->input('last_longitude'),
            'id' => $driverProfileId,
        ]);

        return [
            'status' => 200,
            'data' => [
                'success' => true,
                'message' => 'Driver status updated.',
            ],
        ];
    }

    /**
     * @param array<string, string> $params
     * @return array{status:int,data:array<string,mixed>}
     */
    public function requests(Request $request, array $params = []): array
    {
        $driverProfileId = (int) ($params['driverProfileId'] ?? 0);
        if ($driverProfileId <= 0) {
            return [
                'status' => 422,
                'data' => [
                    'success' => false,
                    'message' => 'driverProfileId is required.',
                ],
            ];
        }

        $pdo = Database::connection();
        $driver = $pdo->prepare("SELECT * FROM driver_profiles WHERE id = :id LIMIT 1");
        $driver->execute(['id' => $driverProfileId]);
        $driverProfile = $driver->fetch();

        if ($driverProfile === false) {
            return [
                'status' => 404,
                'data' => [
                    'success' => false,
                    'message' => 'Driver profile not found.',
                ],
            ];
        }

        $enabledServiceIds = $pdo->prepare(
            "SELECT service_type_id
             FROM driver_service_enablements
             WHERE driver_profile_id = :driver_profile_id
               AND is_enabled = 1"
        );
        $enabledServiceIds->execute(['driver_profile_id' => $driverProfileId]);
        $serviceIds = array_map('intval', array_column($enabledServiceIds->fetchAll(), 'service_type_id'));

        if ($serviceIds === []) {
            $allServices = $pdo->query("SELECT id FROM service_types WHERE is_active = 1 AND supports_driver_mode = 1");
            $serviceIds = array_map('intval', array_column($allServices->fetchAll(), 'id'));
        }

        if ($serviceIds === []) {
            return [
                'status' => 200,
                'data' => [
                    'success' => true,
                    'data' => [
                        'requests' => [],
                    ],
                ],
            ];
        }

        $placeholders = implode(',', array_fill(0, count($serviceIds), '?'));
        $sql = "SELECT
                    b.id,
                    b.booking_reference,
                    b.booking_status,
                    b.pickup_address,
                    b.destination_address,
                    b.estimated_fare,
                    b.offered_fare,
                    b.counter_fare,
                    b.distance_km,
                    b.duration_minutes,
                    b.scheduled_for,
                    st.name AS service_name,
                    st.slug AS service_slug
                FROM bookings b
                INNER JOIN service_types st ON st.id = b.service_type_id
                WHERE b.city_id = ?
                  AND b.driver_profile_id IS NULL
                  AND b.booking_status IN ('pending', 'searching', 'offered', 'scheduled')
                  AND b.service_type_id IN ($placeholders)
                ORDER BY b.scheduled_for IS NOT NULL DESC, b.requested_at ASC
                LIMIT 20";

        $statement = $pdo->prepare($sql);
        $statement->execute(array_merge([(int) $driverProfile['city_id']], $serviceIds));

        return [
            'status' => 200,
            'data' => [
                'success' => true,
                'data' => [
                    'requests' => $statement->fetchAll(),
                ],
            ],
        ];
    }

    /**
     * @param array<string, string> $params
     * @return array{status:int,data:array<string,mixed>}
     */
    public function respond(Request $request, array $params = []): array
    {
        $bookingId = (int) ($params['bookingId'] ?? 0);
        $driverProfileId = (int) $request->input('driver_profile_id', 0);
        $action = (string) $request->input('action', '');

        if ($bookingId <= 0 || $driverProfileId <= 0 || $action === '') {
            return [
                'status' => 422,
                'data' => [
                    'success' => false,
                    'message' => 'bookingId, driver_profile_id, and action are required.',
                ],
            ];
        }

        $pdo = Database::connection();
        $pdo->beginTransaction();

        try {
            $booking = $pdo->prepare("SELECT * FROM bookings WHERE id = :id LIMIT 1 FOR UPDATE");
            $booking->execute(['id' => $bookingId]);
            $bookingRow = $booking->fetch();

            if ($bookingRow === false) {
                throw new RuntimeException('Booking not found.');
            }

            $driver = $pdo->prepare("SELECT * FROM driver_profiles WHERE id = :id LIMIT 1");
            $driver->execute(['id' => $driverProfileId]);
            $driverRow = $driver->fetch();

            if ($driverRow === false) {
                throw new RuntimeException('Driver profile not found.');
            }

            if ($action === 'accept') {
                if ($bookingRow['driver_profile_id'] !== null) {
                    return [
                        'status' => 409,
                        'data' => [
                            'success' => false,
                            'message' => 'This booking is already assigned.',
                        ],
                    ];
                }

                $update = $pdo->prepare(
                    "UPDATE bookings
                     SET driver_profile_id = :driver_profile_id,
                         fleet_owner_id = :fleet_owner_id,
                         booking_status = 'accepted',
                         accepted_at = NOW()
                     WHERE id = :id"
                );
                $update->execute([
                    'driver_profile_id' => $driverProfileId,
                    'fleet_owner_id' => $driverRow['fleet_owner_id'],
                    'id' => $bookingId,
                ]);

                $this->insertStatusHistory(
                    $pdo,
                    $bookingId,
                    (string) $bookingRow['booking_status'],
                    'accepted',
                    (int) $driverRow['user_id'],
                    'Driver accepted booking.'
                );
            } elseif ($action === 'counter_offer') {
                $amount = (float) $request->input('counter_fare', 0);
                if ($amount <= 0) {
                    return [
                        'status' => 422,
                        'data' => [
                            'success' => false,
                            'message' => 'counter_fare is required for counter_offer.',
                        ],
                    ];
                }

                $offer = $pdo->prepare(
                    "INSERT INTO booking_offers
                     (booking_id, driver_profile_id, offered_by_user_id, offer_source, amount, note, status, expires_at)
                     VALUES
                     (:booking_id, :driver_profile_id, :offered_by_user_id, 'driver', :amount, :note, 'pending', DATE_ADD(NOW(), INTERVAL 90 SECOND))"
                );
                $offer->execute([
                    'booking_id' => $bookingId,
                    'driver_profile_id' => $driverProfileId,
                    'offered_by_user_id' => (int) $driverRow['user_id'],
                    'amount' => $amount,
                    'note' => (string) $request->input('note', 'Driver submitted counter offer.'),
                ]);

                $update = $pdo->prepare(
                    "UPDATE bookings
                     SET booking_status = 'offered', counter_fare = :counter_fare
                     WHERE id = :id"
                );
                $update->execute([
                    'counter_fare' => $amount,
                    'id' => $bookingId,
                ]);

                $this->insertStatusHistory(
                    $pdo,
                    $bookingId,
                    (string) $bookingRow['booking_status'],
                    'offered',
                    (int) $driverRow['user_id'],
                    'Driver submitted counter offer.'
                );
            } else {
                $pdo->commit();
                return [
                    'status' => 200,
                    'data' => [
                        'success' => true,
                        'message' => 'Request rejected. No state change stored yet.',
                        'todo' => 'Persist reject reasons and driver-level dispatch cooldown next.',
                    ],
                ];
            }

            $pdo->commit();

            return [
                'status' => 200,
                'data' => [
                    'success' => true,
                    'message' => 'Driver response recorded.',
                ],
            ];
        } catch (\Throwable $exception) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }

            throw $exception;
        }
    }

    private function insertStatusHistory(PDO $pdo, int $bookingId, ?string $oldStatus, string $newStatus, int $changedByUserId, string $note): void
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
}
