<?php

namespace App\Services;

use App\Services\Firebase\FirebaseAdminProject;
use Illuminate\Support\Facades\DB;
use Kreait\Firebase\Exception\FirebaseException;
use Kreait\Firebase\Exception\MessagingException;

class PushNotificationService
{
    public function __construct(
        private readonly FirebaseAdminProject $firebaseAdminProject
    ) {
    }

    /**
     * @param array<int> $userIds
     * @param array<string, scalar|null> $data
     */
    public function sendToUsers(array $userIds, string $title, string $body, array $data = []): void
    {
        $normalizedUserIds = array_values(array_unique(array_filter(
            array_map('intval', $userIds),
            static fn (int $userId): bool => $userId > 0
        )));

        if ($normalizedUserIds === []) {
            return;
        }

        $tokens = DB::table('device_tokens as dt')
            ->leftJoin('notification_preferences as np', 'np.user_id', '=', 'dt.user_id')
            ->whereIn('dt.user_id', $normalizedUserIds)
            ->where(function ($query) {
                $query
                    ->whereNull('np.user_id')
                    ->orWhere('np.push_enabled', 1);
            })
            ->pluck('dt.token')
            ->filter(fn ($token): bool => is_string($token) && trim($token) !== '')
            ->map(fn ($token): string => trim((string) $token))
            ->unique()
            ->values()
            ->all();

        if ($tokens === []) {
            return;
        }

        $message = [
            'notification' => [
                'title' => $title,
                'body' => $body,
            ],
            'data' => $this->normalizeData($data),
            'android' => [
                'priority' => 'high',
                'notification' => [
                    'sound' => 'default',
                ],
            ],
            'apns' => [
                'headers' => [
                    'apns-priority' => '10',
                ],
                'payload' => [
                    'aps' => [
                        'sound' => 'default',
                    ],
                ],
            ],
        ];

        try {
            $report = $this->firebaseAdminProject
                ->messaging()
                ->sendMulticast($message, $tokens);
        } catch (MessagingException|FirebaseException) {
            return;
        }

        $invalidTokens = array_values(array_unique([
            ...$report->invalidTokens(),
            ...$report->unknownTokens(),
        ]));

        if ($invalidTokens !== []) {
            DB::table('device_tokens')
                ->whereIn('token', $invalidTokens)
                ->delete();
        }
    }

    /**
     * @param array<string, scalar|null> $data
     * @return array<string, string>
     */
    private function normalizeData(array $data): array
    {
        $normalized = [];

        foreach ($data as $key => $value) {
            if (! is_string($key) || trim($key) === '' || $value === null) {
                continue;
            }

            $normalized[$key] = match (true) {
                is_bool($value) => $value ? '1' : '0',
                default => (string) $value,
            };
        }

        return $normalized;
    }
}
