<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Validation\ValidationException;

class GoogleAuthService
{
    public function verify(string $idToken): array
    {
        if (app()->environment('local') && str_starts_with($idToken, 'dev-google-token:')) {
            [, $email] = explode(':', $idToken, 2);
            return ['sub' => sha1($email), 'email' => $email, 'name' => strtok($email, '@'), 'email_verified' => true];
        }

        $response = Http::timeout(10)->get('https://oauth2.googleapis.com/tokeninfo', ['id_token' => $idToken]);
        if (!$response->ok()) {
            throw ValidationException::withMessages(['google_id_token' => 'Google token could not be verified.']);
        }

        $payload = $response->json();
        $clientId = config('services.google.client_id');
        if ($clientId && ($payload['aud'] ?? null) !== $clientId) {
            throw ValidationException::withMessages(['google_id_token' => 'Google token audience does not match this app.']);
        }

        return $payload;
    }

    public function verifyAccessToken(string $accessToken): array
    {
        $response = Http::withToken($accessToken)
            ->timeout(10)
            ->get('https://www.googleapis.com/oauth2/v3/userinfo');

        if (! $response->ok()) {
            throw ValidationException::withMessages(['google_access_token' => 'Google account could not be verified.']);
        }

        return $response->json();
    }
}
