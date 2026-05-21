<?php

declare(strict_types=1);

namespace App\Support;

final class BookingCalculator
{
    /**
     * @param array<string, mixed> $pricingRule
     * @return array<string, float|string|int|null>
     */
    public static function estimate(array $pricingRule, float $distanceKm, int $durationMinutes): array
    {
        $pricingModel = (string) ($pricingRule['pricing_model'] ?? 'distance_time');
        $baseFare = (float) ($pricingRule['base_fare'] ?? 0);
        $perKm = (float) ($pricingRule['per_km_fare'] ?? 0);
        $perMinute = (float) ($pricingRule['per_minute_fare'] ?? 0);
        $minimumFare = (float) ($pricingRule['minimum_fare'] ?? 0);
        $bookingFee = (float) ($pricingRule['booking_fee'] ?? 0);
        $platformFee = (float) ($pricingRule['platform_fee'] ?? 0);

        $subtotal = match ($pricingModel) {
            'fixed' => $minimumFare,
            'hourly' => $baseFare * max(1, (int) ceil(max($durationMinutes, 60) / 60)),
            'daily' => $baseFare * max(1, (int) ceil(max($durationMinutes, 1440) / 1440)),
            default => $baseFare + ($distanceKm * $perKm) + ($durationMinutes * $perMinute),
        };

        $subtotal = max($minimumFare, $subtotal);
        $total = $subtotal + $bookingFee + $platformFee;

        return [
            'pricing_model' => $pricingModel,
            'distance_km' => round($distanceKm, 2),
            'duration_minutes' => $durationMinutes,
            'subtotal' => round($subtotal, 2),
            'booking_fee' => round($bookingFee, 2),
            'platform_fee' => round($platformFee, 2),
            'total_fare' => round($total, 2),
        ];
    }
}
