<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Throwable;

class HealthController extends Controller
{
    public function __invoke(): JsonResponse
    {
        $database = $this->databaseStatus();
        $status = $database['status'] === 'unreachable' ? 'degraded' : 'ok';

        return response()->json([
            'status' => $status,
            'app' => config('onwayrides.platform.name'),
            'environment' => app()->environment(),
            'api_version' => config('onwayrides.api_version'),
            'timestamp' => now()->toIso8601String(),
            'database' => $database,
        ], $status === 'ok' ? 200 : 503);
    }

    /**
     * @return array<string, mixed>
     */
    private function databaseStatus(): array
    {
        $connection = (string) config('database.default');
        $database = (string) config("database.connections.{$connection}.database");

        if (! in_array($connection, ['mysql', 'mariadb'], true) || $database === '') {
            return [
                'connection' => $connection,
                'database' => $database !== '' ? $database : null,
                'status' => 'not_configured',
            ];
        }

        try {
            DB::connection($connection)->select('SELECT 1');

            return [
                'connection' => $connection,
                'database' => $database,
                'status' => 'reachable',
            ];
        } catch (Throwable $exception) {
            $payload = [
                'connection' => $connection,
                'database' => $database,
                'status' => 'unreachable',
            ];

            if (config('app.debug')) {
                $payload['error'] = $exception->getMessage();
            }

            return $payload;
        }
    }
}
