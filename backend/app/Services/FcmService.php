<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use RuntimeException;

class FcmService
{
    public function sendToUser(User $user, string $title, string $body, array $data = []): bool
    {
        if (! $user->fcm_token) {
            return false;
        }

        $data = $this->stringifyData($data);
        $attempts = [];

        if (filled(config('services.firebase.credentials'))) {
            $attempts['firebase_v1'] = fn () => $this->sendV1($user->fcm_token, $title, $body, $data);
        }

        if (filled(config('services.fcm.server_key'))) {
            $attempts['legacy_server_key'] = fn () => $this->sendLegacy($user->fcm_token, $title, $body, $data);
        }

        if ($attempts === []) {
            $sensitive = ($data['type'] ?? null) === 'delivery_code';
            $loggedData = $data;
            unset($loggedData['delivery_code']);
            Log::info('FCM notification skipped because credentials are not configured.', [
                'title' => $title,
                'body' => $sensitive ? '[redacted delivery code notification]' : $body,
                'data' => $loggedData,
                'user_id' => $user->id,
            ]);

            return false;
        }

        $lastTransport = null;
        $lastError = null;
        foreach ($attempts as $transport => $send) {
            try {
                return $send();
            } catch (\Throwable $error) {
                $lastTransport = $transport;
                $lastError = $error;
                Log::warning('FCM notification transport failed.', [
                    'transport' => $transport,
                    'user_id' => $user->id,
                    'title' => $title,
                    'error' => $error->getMessage(),
                    'will_retry' => count($attempts) > 1 && $transport !== array_key_last($attempts),
                ]);
            }
        }

        if ($lastError) {
            Log::warning('FCM notification failed.', [
                'user_id' => $user->id,
                'title' => $title,
                'transport' => $lastTransport,
                'error' => $lastError->getMessage(),
            ]);
        }

        return false;
    }

    private function sendV1(string $token, string $title, string $body, array $data): bool
    {
        $projectId = config('services.firebase.project_id');
        if (! $projectId) {
            throw new RuntimeException('FIREBASE_PROJECT_ID is not configured.');
        }

        Http::withToken($this->accessToken())
            ->post("https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send", [
                'message' => [
                    'token' => $token,
                    'notification' => ['title' => $title, 'body' => $body],
                    'data' => $data,
                    'android' => [
                        'priority' => 'HIGH',
                        'notification' => [
                            'channel_id' => 'chat_messages',
                            'sound' => 'default',
                        ],
                    ],
                    'apns' => [
                        'payload' => [
                            'aps' => ['sound' => 'default'],
                        ],
                    ],
                ],
            ])
            ->throw();

        return true;
    }

    private function sendLegacy(string $token, string $title, string $body, array $data): bool
    {
        Http::withHeaders(['Authorization' => 'key='.config('services.fcm.server_key')])
            ->post('https://fcm.googleapis.com/fcm/send', [
                'to' => $token,
                'priority' => 'high',
                'notification' => ['title' => $title, 'body' => $body, 'sound' => 'default'],
                'data' => $data,
            ])
            ->throw();

        return true;
    }

    private function accessToken(): string
    {
        $credentials = $this->firebaseCredentials();
        $clientEmail = $credentials['client_email'] ?? null;
        $privateKey = $credentials['private_key'] ?? null;

        if (! $clientEmail || ! $privateKey) {
            throw new RuntimeException('Firebase service account credentials are incomplete.');
        }

        return Cache::remember('firebase_access_token_'.md5($clientEmail), 3300, function () use ($clientEmail, $privateKey) {
            $now = time();
            $assertion = $this->jwt([
                'alg' => 'RS256',
                'typ' => 'JWT',
            ], [
                'iss' => $clientEmail,
                'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
                'aud' => 'https://oauth2.googleapis.com/token',
                'iat' => $now,
                'exp' => $now + 3600,
            ], $privateKey);

            $response = Http::asForm()
                ->post('https://oauth2.googleapis.com/token', [
                    'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                    'assertion' => $assertion,
                ])
                ->throw()
                ->json();

            return $response['access_token'] ?? throw new RuntimeException('Firebase access token was not returned.');
        });
    }

    /**
     * @return array<string, mixed>
     */
    private function firebaseCredentials(): array
    {
        $source = trim((string) config('services.firebase.credentials'));
        if ($source === '') {
            throw new RuntimeException('Firebase service account credentials are not configured.');
        }

        if ($path = $this->firebaseCredentialsPath($source)) {
            $contents = (string) file_get_contents($path);
        } elseif (str_starts_with($source, 'base64:')) {
            $contents = (string) base64_decode(substr($source, 7), true);
        } elseif (str_starts_with($source, '{')) {
            $contents = $source;
        } else {
            throw new RuntimeException('Firebase service account file is not readable.');
        }

        $credentials = json_decode($contents, true);
        if (! is_array($credentials)) {
            throw new RuntimeException('Firebase service account file is invalid JSON.');
        }

        return $credentials;
    }

    private function firebaseCredentialsPath(string $source): ?string
    {
        $candidates = str_starts_with($source, '/')
            ? [$source]
            : [
                base_path($source),
                storage_path($source),
                storage_path('app/'.$source),
            ];

        foreach ($candidates as $path) {
            if (is_readable($path)) {
                return $path;
            }
        }

        return null;
    }

    /**
     * @param  array<string, mixed>  $header
     * @param  array<string, mixed>  $payload
     */
    private function jwt(array $header, array $payload, string $privateKey): string
    {
        $segments = [
            $this->base64UrlEncode(json_encode($header, JSON_THROW_ON_ERROR)),
            $this->base64UrlEncode(json_encode($payload, JSON_THROW_ON_ERROR)),
        ];
        $signingInput = implode('.', $segments);

        if (! openssl_sign($signingInput, $signature, $privateKey, OPENSSL_ALGO_SHA256)) {
            throw new RuntimeException('Unable to sign Firebase JWT.');
        }

        $segments[] = $this->base64UrlEncode($signature);

        return implode('.', $segments);
    }

    private function base64UrlEncode(string $value): string
    {
        return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
    }

    /**
     * @return array<string, string>
     */
    private function stringifyData(array $data): array
    {
        return collect($data)
            ->mapWithKeys(fn ($value, $key) => [
                (string) $key => is_scalar($value) || $value === null
                    ? (string) $value
                    : json_encode($value, JSON_THROW_ON_ERROR),
            ])
            ->all();
    }
}
