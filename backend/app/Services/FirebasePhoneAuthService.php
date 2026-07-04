<?php

namespace App\Services;

use App\Models\AppSetting;
use Illuminate\Support\Facades\Http;
use Illuminate\Validation\ValidationException;

class FirebasePhoneAuthService
{
    public function verifyPhoneToken(string $idToken, string $phone): void
    {
        if (app()->environment('local') && str_starts_with($idToken, 'dev-firebase-phone-token:')) {
            abort_unless(substr($idToken, 25) === $phone, 422, 'Firebase phone token does not match this phone.');
            return;
        }

        $response = Http::timeout(10)->get('https://oauth2.googleapis.com/tokeninfo', ['id_token' => $idToken]);
        if (!$response->ok()) {
            throw ValidationException::withMessages(['firebase_id_token' => 'Firebase phone token could not be verified.']);
        }

        $payload = $response->json();
        $projectId = AppSetting::get('firebase_project_id', config('services.firebase.project_id'));
        if ($projectId && ($payload['aud'] ?? null) !== $projectId) {
            throw ValidationException::withMessages(['firebase_id_token' => 'Firebase token audience does not match this project.']);
        }

        if (($payload['phone_number'] ?? null) !== $phone) {
            throw ValidationException::withMessages(['firebase_id_token' => 'Firebase token phone number does not match.']);
        }
    }
}
