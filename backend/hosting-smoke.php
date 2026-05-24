<?php

declare(strict_types=1);

use Illuminate\Contracts\Http\Kernel as HttpKernelContract;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

ini_set('display_errors', '1');
ini_set('html_errors', '0');
error_reporting(E_ALL);

$basePath = __DIR__;
$baseUrl = $argv[1] ?? null;
$results = [];
$steps = [];

function smokeTrace(array &$steps, string $message): void
{
    $steps[] = '['.date('c')."] {$message}";
}

function smokeAdd(array &$results, string $name, bool $ok, string $details): void
{
    $results[] = [
        'name' => $name,
        'ok' => $ok,
        'details' => $details,
    ];
}

function smokePrint(array $results, array $steps): void
{
    echo "OnWay Rides Hosting Smoke Test\n";
    echo "==============================\n\n";

    foreach ($results as $result) {
        echo ($result['ok'] ? '[PASS] ' : '[FAIL] ').$result['name']."\n";
        echo '       '.$result['details']."\n";
    }

    echo "\nTrace\n";
    echo "-----\n";

    foreach ($steps as $step) {
        echo $step."\n";
    }
}

function smokeHttp(string $url): array
{
    $ch = curl_init($url);

    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_TIMEOUT => 20,
        CURLOPT_CONNECTTIMEOUT => 10,
        CURLOPT_SSL_VERIFYPEER => true,
        CURLOPT_SSL_VERIFYHOST => 2,
        CURLOPT_HTTPHEADER => [
            'Accept: application/json',
        ],
    ]);

    $body = curl_exec($ch);
    $error = curl_error($ch);
    $status = (int) curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
    curl_close($ch);

    return [
        'ok' => $error === '' && $status > 0 && $status < 500,
        'status' => $status,
        'body' => is_string($body) ? $body : '',
        'error' => $error,
    ];
}

register_shutdown_function(function () use (&$results, &$steps): void {
    $error = error_get_last();

    if ($error === null) {
        return;
    }

    smokeAdd(
        $results,
        'Fatal shutdown',
        false,
        sprintf(
            '%s in %s:%d',
            $error['message'] ?? 'unknown error',
            $error['file'] ?? 'unknown file',
            $error['line'] ?? 0
        )
    );

    smokePrint($results, $steps);
});

try {
    smokeTrace($steps, 'CLI START');

    smokeAdd($results, 'PHP version', version_compare(PHP_VERSION, '8.3.0', '>='), 'Current PHP version: '.PHP_VERSION);
    smokeAdd($results, '.env file', is_file($basePath.'/.env'), $basePath.'/.env');
    smokeAdd($results, 'Firebase credentials file', is_file($basePath.'/storage/app/firebase-service-account.json'), $basePath.'/storage/app/firebase-service-account.json');

    smokeTrace($steps, 'AUTOLOAD');
    require $basePath.'/vendor/autoload.php';
    smokeAdd($results, 'Composer autoload', true, 'vendor/autoload.php loaded');

    smokeTrace($steps, 'BOOTSTRAP');
    $app = require $basePath.'/bootstrap/app.php';
    smokeAdd($results, 'Laravel bootstrap', true, 'bootstrap/app.php loaded');

    smokeTrace($steps, 'MAKE KERNEL');
    $kernel = $app->make(HttpKernelContract::class);
    smokeAdd($results, 'HTTP kernel resolution', true, 'Kernel resolved');

    smokeTrace($steps, 'ROUTES');
    $routes = $app->make('router')->getRoutes();
    foreach (['api.health', 'api.bootstrap', 'api.auth.login', 'api.auth.onboarding'] as $routeName) {
        smokeAdd($results, 'Named route', $routes->getByName($routeName) !== null, $routeName);
    }

    smokeTrace($steps, 'DATABASE');
    try {
        DB::connection()->select('SELECT 1');
        smokeAdd($results, 'Database connectivity', true, 'SELECT 1 succeeded');
    } catch (Throwable $exception) {
        smokeAdd($results, 'Database connectivity', false, $exception->getMessage());
    }

    foreach (['/', '/up', '/api/health', '/api/bootstrap'] as $path) {
        smokeTrace($steps, 'HANDLE '.$path);

        try {
            $request = Request::create($path, 'GET');
            $response = $kernel->handle($request);
            $body = trim((string) $response->getContent());
            $snippet = $body === '' ? '[empty body]' : mb_substr($body, 0, 180);

            smokeAdd(
                $results,
                'Local request '.$path,
                $response->getStatusCode() < 500,
                'HTTP '.$response->getStatusCode().' body: '.$snippet
            );

            $kernel->terminate($request, $response);
        } catch (Throwable $exception) {
            smokeAdd(
                $results,
                'Local request '.$path,
                false,
                get_class($exception).': '.$exception->getMessage().' @ '.$exception->getFile().':'.$exception->getLine()
            );
        }
    }

    if (is_string($baseUrl) && trim($baseUrl) !== '') {
        $trimmedBaseUrl = rtrim(trim($baseUrl), '/');

        foreach (['/api/health', '/api/bootstrap'] as $path) {
            $url = $trimmedBaseUrl.$path;
            smokeTrace($steps, 'HTTP '.$url);

            $http = smokeHttp($url);
            $snippet = $http['body'] === '' ? '[empty body]' : mb_substr(trim($http['body']), 0, 180);
            $details = $http['error'] !== ''
                ? $http['error']
                : 'HTTP '.$http['status'].' body: '.$snippet;

            smokeAdd($results, 'Remote request '.$url, $http['ok'], $details);
        }
    } else {
        smokeAdd(
            $results,
            'Remote HTTP checks',
            true,
            'Skipped. Run: ea-php83 hosting-smoke.php https://api.onwayrides.com'
        );
    }

    smokeTrace($steps, 'DONE');
    smokePrint($results, $steps);
} catch (Throwable $exception) {
    smokeAdd(
        $results,
        'Unhandled exception',
        false,
        get_class($exception).': '.$exception->getMessage().' @ '.$exception->getFile().':'.$exception->getLine()
    );

    smokePrint($results, $steps);
    exit(1);
}
