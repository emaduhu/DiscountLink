<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class FcmService
{
    public function sendToUser(User $user, string $title, string $body, array $data = []): void
    {
        if (!$user->fcm_token) {
            return;
        }
        if (!config('services.fcm.server_key') || app()->environment('local')) {
            Log::info('FCM notification', compact('title', 'body', 'data') + ['user_id' => $user->id]);
            return;
        }
        Http::withToken(config('services.fcm.server_key'))->post('https://fcm.googleapis.com/fcm/send', [
            'to' => $user->fcm_token,
            'notification' => ['title' => $title, 'body' => $body],
            'data' => $data,
        ])->throw();
    }
}
