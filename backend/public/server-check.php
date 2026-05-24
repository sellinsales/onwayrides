<?php

declare(strict_types=1);

$basePath = dirname(__DIR__);
$checks = [];

function add_check(array &$checks, string $label, bool $ok, string $details): void
{
    $checks[] = [
        'label' => $label,
        'ok' => $ok,
        'details' => $details,
    ];
}

function env_file_value(string $envPath, string $key): ?string
{
    if (!is_file($envPath) || !is_readable($envPath)) {
        return null;
    }

    $lines = file($envPath, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    if ($lines === false) {
        return null;
    }

    foreach ($lines as $line) {
        if (str_starts_with(trim($line), '#')) {
            continue;
        }

        if (!str_contains($line, '=')) {
            continue;
        }

        [$name, $value] = explode('=', $line, 2);
        if (trim($name) !== $key) {
            continue;
        }

        return trim($value, " \t\n\r\0\x0B\"'");
    }

    return null;
}

$envPath = $basePath . DIRECTORY_SEPARATOR . '.env';
$vendorAutoload = $basePath . DIRECTORY_SEPARATOR . 'vendor' . DIRECTORY_SEPARATOR . 'autoload.php';
$bootstrapApp = $basePath . DIRECTORY_SEPARATOR . 'bootstrap' . DIRECTORY_SEPARATOR . 'app.php';
$storagePath = $basePath . DIRECTORY_SEPARATOR . 'storage';
$logsPath = $storagePath . DIRECTORY_SEPARATOR . 'logs';
$cachePath = $basePath . DIRECTORY_SEPARATOR . 'bootstrap' . DIRECTORY_SEPARATOR . 'cache';
$requiredExtensions = [
    'bcmath',
    'ctype',
    'curl',
    'dom',
    'fileinfo',
    'json',
    'mbstring',
    'openssl',
    'pdo',
    'pdo_mysql',
    'session',
    'tokenizer',
    'xml',
];

add_check(
    $checks,
    'PHP version',
    version_compare(PHP_VERSION, '8.3.0', '>='),
    'Current PHP version: ' . PHP_VERSION
);

add_check(
    $checks,
    'Document root',
    true,
    $_SERVER['DOCUMENT_ROOT'] ?? 'unknown'
);

add_check(
    $checks,
    'Laravel base path',
    is_dir($basePath),
    $basePath
);

add_check(
    $checks,
    'vendor/autoload.php',
    is_file($vendorAutoload) && is_readable($vendorAutoload),
    $vendorAutoload
);

add_check(
    $checks,
    'bootstrap/app.php',
    is_file($bootstrapApp) && is_readable($bootstrapApp),
    $bootstrapApp
);

add_check(
    $checks,
    '.env file',
    is_file($envPath) && is_readable($envPath),
    $envPath
);

add_check(
    $checks,
    'storage/logs writable',
    is_dir($logsPath) && is_writable($logsPath),
    $logsPath
);

add_check(
    $checks,
    'bootstrap/cache writable',
    is_dir($cachePath) && is_writable($cachePath),
    $cachePath
);

foreach ($requiredExtensions as $extension) {
    add_check(
        $checks,
        'PHP extension: ' . $extension,
        extension_loaded($extension),
        extension_loaded($extension) ? 'loaded' : 'missing'
    );
}

$appKey = env_file_value($envPath, 'APP_KEY');
$dbHost = env_file_value($envPath, 'DB_HOST');
$dbDatabase = env_file_value($envPath, 'DB_DATABASE');
$dbUsername = env_file_value($envPath, 'DB_USERNAME');
$firebaseProjectId = env_file_value($envPath, 'FIREBASE_PROJECT_ID');
$firebaseCredentialsJson = env_file_value($envPath, 'FIREBASE_CREDENTIALS_JSON');

add_check(
    $checks,
    'APP_KEY present',
    !empty($appKey),
    empty($appKey) ? 'APP_KEY is missing' : 'APP_KEY is set'
);

add_check(
    $checks,
    'Database env values',
    !empty($dbHost) && !empty($dbDatabase) && !empty($dbUsername),
    sprintf(
        'DB_HOST=%s, DB_DATABASE=%s, DB_USERNAME=%s',
        $dbHost ?: 'missing',
        $dbDatabase ?: 'missing',
        $dbUsername ?: 'missing'
    )
);

add_check(
    $checks,
    'Firebase env values',
    !empty($firebaseProjectId) && !empty($firebaseCredentialsJson),
    sprintf(
        'FIREBASE_PROJECT_ID=%s, FIREBASE_CREDENTIALS_JSON=%s',
        $firebaseProjectId ?: 'missing',
        $firebaseCredentialsJson ? 'set' : 'missing'
    )
);

$failedCount = count(array_filter($checks, static fn (array $check): bool => !$check['ok']));
http_response_code($failedCount > 0 ? 500 : 200);
?>
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>OnWay Rides Server Check</title>
  <style>
    body { font-family: Arial, sans-serif; background: #f6f7fb; color: #14213d; margin: 0; padding: 24px; }
    .wrap { max-width: 980px; margin: 0 auto; background: #fff; border-radius: 16px; padding: 24px; box-shadow: 0 20px 50px rgba(20,33,61,.08); }
    h1 { margin-top: 0; }
    .summary { margin-bottom: 20px; font-size: 16px; }
    table { width: 100%; border-collapse: collapse; }
    th, td { text-align: left; padding: 12px; border-bottom: 1px solid #e5e7ef; vertical-align: top; }
    th { background: #f1f4f8; }
    .ok { color: #127a3f; font-weight: 700; }
    .fail { color: #b42318; font-weight: 700; }
    code { background: #f1f4f8; padding: 2px 6px; border-radius: 6px; }
  </style>
</head>
<body>
  <div class="wrap">
    <h1>OnWay Rides Server Check</h1>
    <p class="summary">
      Result: <strong class="<?php echo $failedCount > 0 ? 'fail' : 'ok'; ?>">
        <?php echo $failedCount > 0 ? $failedCount . ' failed check(s)' : 'all checks passed'; ?>
      </strong>
    </p>
    <table>
      <thead>
        <tr>
          <th>Check</th>
          <th>Status</th>
          <th>Details</th>
        </tr>
      </thead>
      <tbody>
        <?php foreach ($checks as $check): ?>
          <tr>
            <td><?php echo htmlspecialchars($check['label'], ENT_QUOTES, 'UTF-8'); ?></td>
            <td class="<?php echo $check['ok'] ? 'ok' : 'fail'; ?>">
              <?php echo $check['ok'] ? 'PASS' : 'FAIL'; ?>
            </td>
            <td><code><?php echo htmlspecialchars($check['details'], ENT_QUOTES, 'UTF-8'); ?></code></td>
          </tr>
        <?php endforeach; ?>
      </tbody>
    </table>
  </div>
</body>
</html>
