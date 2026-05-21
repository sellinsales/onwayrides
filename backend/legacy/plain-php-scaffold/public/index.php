<?php

declare(strict_types=1);

date_default_timezone_set('UTC');

spl_autoload_register(static function (string $class): void {
    $prefix = 'App\\';
    $baseDir = dirname(__DIR__) . '/app/';

    if (!str_starts_with($class, $prefix)) {
        return;
    }

    $relativeClass = substr($class, strlen($prefix));
    $file = $baseDir . str_replace('\\', '/', $relativeClass) . '.php';

    if (is_file($file)) {
        require_once $file;
    }
});

use App\Controllers\AuthController;
use App\Controllers\BookingController;
use App\Controllers\BootstrapController;
use App\Controllers\DriverController;
use App\Controllers\HealthController;
use App\Support\Env;
use App\Support\JsonResponse;
use App\Support\Request;
use App\Support\Router;

Env::load(dirname(__DIR__) . '/.env');

$allowedOrigins = array_filter(array_map('trim', explode(',', Env::get('CORS_ALLOWED_ORIGINS', '*'))));
$origin = $_SERVER['HTTP_ORIGIN'] ?? '';

if (in_array('*', $allowedOrigins, true)) {
    header('Access-Control-Allow-Origin: *');
} elseif ($origin !== '' && in_array($origin, $allowedOrigins, true)) {
    header('Access-Control-Allow-Origin: ' . $origin);
    header('Vary: Origin');
}

header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
header('Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS');
header('Content-Type: application/json; charset=utf-8');

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'OPTIONS') {
    http_response_code(204);
    exit;
}

$router = new Router();
$request = Request::fromGlobals();

$healthController = new HealthController();
$bootstrapController = new BootstrapController();
$authController = new AuthController();
$bookingController = new BookingController();
$driverController = new DriverController();

$router->get('/api/health', [$healthController, 'index']);
$router->get('/api/bootstrap', [$bootstrapController, 'index']);
$router->post('/api/auth/sync', [$authController, 'sync']);
$router->post('/api/bookings/estimate', [$bookingController, 'estimate']);
$router->post('/api/bookings', [$bookingController, 'create']);
$router->get('/api/bookings/{reference}', [$bookingController, 'show']);
$router->post('/api/drivers/status', [$driverController, 'updateStatus']);
$router->get('/api/drivers/{driverProfileId}/requests', [$driverController, 'requests']);
$router->post('/api/drivers/requests/{bookingId}/respond', [$driverController, 'respond']);

try {
    $response = $router->dispatch($request);
    JsonResponse::send($response['data'] ?? null, $response['status'] ?? 200);
} catch (Throwable $exception) {
    JsonResponse::send([
        'success' => false,
        'message' => 'Server error.',
        'error' => Env::get('APP_DEBUG', 'false') === 'true' ? $exception->getMessage() : null,
    ], 500);
}
