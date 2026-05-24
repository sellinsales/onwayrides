<?php

declare(strict_types=1);

use Illuminate\Contracts\Http\Kernel as HttpKernelContract;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

ini_set('display_errors', '1');
ini_set('html_errors', '0');
error_reporting(E_ALL);

$steps = [];
$results = [];
$fatalError = null;
$basePath = dirname(__DIR__);

function smoke_step(array &$steps, string $message): void
{
    $steps[] = '['.date('c')."] {$message}";
}

function smoke_result(array &$results, string $name, bool $ok, string $details): void
{
    $results[] = [
        'name' => $name,
        'ok' => $ok,
        'details' => $details,
    ];
}

function smoke_render(array $steps, array $results, ?array $fatalError = null): void
{
    if (! headers_sent()) {
        header('Content-Type: text/plain; charset=utf-8');
    }

    echo "OnWay Rides Production Smoke Test\n";
    echo "=================================\n\n";

    foreach ($results as $result) {
        echo ($result['ok'] ? '[PASS] ' : '[FAIL] ').$result['name']."\n";
        echo '       '.$result['details']."\n";
    }

    if ($fatalError !== null) {
        echo "\n[FATAL]\n";
        echo 'type: '.($fatalError['type'] ?? 'unknown')."\n";
        echo 'message: '.($fatalError['message'] ?? 'unknown')."\n";
        echo 'file: '.($fatalError['file'] ?? 'unknown')."\n";
        echo 'line: '.($fatalError['line'] ?? 0)."\n";
    }

    echo "\nExecution trace\n";
    echo "---------------\n";
    foreach ($steps as $step) {
        echo $step."\n";
    }
}

register_shutdown_function(function () use (&$steps, &$results, &$fatalError): void {
    $error = error_get_last();

    if ($error !== null) {
        $fatalError = $error;
        http_response_code(500);
        smoke_render($steps, $results, $fatalError);
    }
});

smoke_step($steps, 'START');

smoke_result(
    $results,
    'PHP version',
    version_compare(PHP_VERSION, '8.3.0', '>='),
    'Current PHP version: '.PHP_VERSION
);

smoke_result(
    $results,
    'Document root',
    true,
    (string) ($_SERVER['DOCUMENT_ROOT'] ?? 'unknown')
);

smoke_step($steps, 'AUTOLOAD');
require $basePath.'/vendor/autoload.php';
smoke_result($results, 'Composer autoload', true, 'vendor/autoload.php loaded');

smoke_step($steps, 'BOOTSTRAP');
$app = require $basePath.'/bootstrap/app.php';
smoke_result($results, 'Laravel bootstrap', true, 'bootstrap/app.php loaded');

$providerChecks = [
    'Laravel\\Pail\\PailServiceProvider',
    'NunoMaduro\\Collision\\Adapters\\Laravel\\CollisionServiceProvider',
    'Termwind\\Laravel\\TermwindServiceProvider',
    'Laravel\\Tinker\\TinkerServiceProvider',
];

foreach ($providerChecks as $providerClass) {
    smoke_result(
        $results,
        'Provider class check',
        true,
        $providerClass.' => '.(class_exists($providerClass) ? 'exists' : 'missing')
    );
}

smoke_step($steps, 'MAKE KERNEL');
$kernel = $app->make(HttpKernelContract::class);
smoke_result($results, 'HTTP kernel resolution', true, 'Kernel resolved successfully');

smoke_step($steps, 'CHECK ROUTES');
$router = $app->make('router');
$routes = $router->getRoutes();
$requiredNamedRoutes = [
    'api.health',
    'api.bootstrap',
    'api.auth.login',
];

foreach ($requiredNamedRoutes as $routeName) {
    smoke_result(
        $results,
        'Named route',
        $routes->getByName($routeName) !== null,
        $routeName
    );
}

smoke_step($steps, 'CHECK DATABASE');
try {
    DB::connection()->select('SELECT 1');
    smoke_result($results, 'Database connectivity', true, 'SELECT 1 succeeded');
} catch (Throwable $exception) {
    smoke_result($results, 'Database connectivity', false, $exception->getMessage());
}

$requestPaths = [
    '/' => 'web root',
    '/up' => 'laravel health path',
    '/api/health' => 'api health',
    '/api/bootstrap' => 'api bootstrap',
];

foreach ($requestPaths as $path => $label) {
    smoke_step($steps, 'HANDLE '.$path);

    try {
        $request = Request::create($path, 'GET');
        $response = $kernel->handle($request);
        $content = trim((string) $response->getContent());
        $snippet = $content === '' ? '[empty body]' : mb_substr($content, 0, 180);

        smoke_result(
            $results,
            'HTTP request '.$label,
            $response->getStatusCode() < 500,
            'HTTP '.$response->getStatusCode().' body: '.$snippet
        );

        $kernel->terminate($request, $response);
    } catch (Throwable $exception) {
        smoke_result(
            $results,
            'HTTP request '.$label,
            false,
            get_class($exception).': '.$exception->getMessage().' @ '.$exception->getFile().':'.$exception->getLine()
        );
    }
}

smoke_step($steps, 'DONE');
smoke_render($steps, $results);
