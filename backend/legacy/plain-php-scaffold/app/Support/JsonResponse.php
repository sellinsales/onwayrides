<?php

declare(strict_types=1);

namespace App\Support;

final class JsonResponse
{
    /**
     * @param array<string, mixed>|null $payload
     */
    public static function send(?array $payload, int $status = 200): void
    {
        http_response_code($status);
        echo json_encode($payload ?? ['success' => true], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
        exit;
    }
}
