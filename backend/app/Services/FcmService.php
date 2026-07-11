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
        if (!$user->fcm_token) {
            return false;
        }

        $data = $this->stringifyData($data);

        try {
            if (config('services.firebase.credentials')) {
                return $this->sendV1($user->fcm_token, $title, $body, $data);
            }

            if (config('services.fcm.server_key')) {
                return $this->sendLegacy($user->fcm_token, $title, $body, $data);
            }

            Log::info('FCM notification skipped because credentials are not configured.', compact('title', 'body', 'data') + [
                'user_id' => $user->id,
            ]);
            return false;
        } catch (\Throwable $error) {
            Log::warning('FCM notification failed.', [
                'user_id' => $user->id,
                'title' => $title,
                'error' => $error->getMessage(),
            ]);
            return false;
        }
    }

    private function sendV1(string $token, string $title, string $body, array $data): bool
    {
        $projectId = config('services.firebase.project_id');
        if (!$projectId) {
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

        if (!$clientEmail || !$privateKey) {
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
        $path = config('services.firebase.credentials');
        if (!$path || !is_readable($path)) {
            throw new RuntimeException('Firebase service account file is not readable.');
        }

        $credentials = json_decode((string) file_get_contents($path), true);
        if (!is_array($credentials)) {
            throw new RuntimeException('Firebase service account file is invalid JSON.');
        }

        return $credentials;
    }

    /**
     * @param array<string, mixed> $header
     * @param array<string, mixed> $payload
     */
    private function jwt(array $header, array $payload, string $privateKey): string
    {
        $segments = [
            $this->base64UrlEncode(json_encode($header, JSON_THROW_ON_ERROR)),
            $this->base64UrlEncode(json_encode($payload, JSON_THROW_ON_ERROR)),
        ];
        $signingInput = implode('.', $segments);

        if (!openssl_sign($signingInput, $signature, $privateKey, OPENSSL_ALGO_SHA256)) {
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
