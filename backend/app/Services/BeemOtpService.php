<?php

namespace App\Services;

use App\Models\AppSetting;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use RuntimeException;

class BeemOtpService
{
    public function send(string $phone, string $code): ?string
    {
        return $this->sendMessage($phone, "Your DiscountLink verification code is {$code}.");
    }

    public function sendMessage(string $phone, string $message): ?string
    {
        $apiKey = config('services.beem.api_key');
        $secretKey = config('services.beem.secret_key');
        if (app()->environment('local')) {
            Log::info('DiscountLink SMS', ['phone' => $phone, 'message' => $message]);
            return 'local-log';
        }
        if (! $apiKey || ! $secretKey) {
            throw new RuntimeException('Beem SMS credentials are not configured.');
        }

        $phone = preg_replace('/\D+/', '', $phone) ?? '';
        if (! preg_match('/^\d{12}$/', $phone)) {
            throw new RuntimeException('Beem SMS destination phone must contain exactly 12 digits.');
        }
        $senderId = AppSetting::get('beem_sender_id', config('services.beem.sender_id'));
        $baseUrl = AppSetting::get('beem_base_url', config('services.beem.base_url'));

        $response = Http::withBasicAuth($apiKey, $secretKey)
            ->timeout(15)
            ->acceptJson()
            ->post(rtrim($baseUrl, '/').'/sms/v1/send', [
                'source_addr' => $senderId,
                'encoding' => 0,
                'schedule_time' => '',
                'message' => $message,
                'recipients' => [['recipient_id' => 1, 'dest_addr' => $phone]],
            ]);

        if ($response->failed()) {
            Log::warning('DiscountLink Beem SMS rejected.', [
                'phone' => $phone,
                'sender_id' => $senderId,
                'status' => $response->status(),
                'body' => substr($response->body(), 0, 1000),
            ]);
            $response->throw();
        }

        $payload = $response->json();
        $requestId = (string) data_get($payload, 'request_id');
        if ($requestId === '' || data_get($payload, 'successful') === false) {
            Log::warning('DiscountLink Beem SMS response was not accepted.', [
                'phone' => $phone,
                'sender_id' => $senderId,
                'status' => $response->status(),
                'body' => substr($response->body(), 0, 1000),
            ]);
            throw new RuntimeException('Beem SMS was not accepted by the provider.');
        }

        Log::info('DiscountLink Beem SMS accepted.', [
            'phone' => $phone,
            'sender_id' => $senderId,
            'request_id' => $requestId,
        ]);

        return $requestId;
    }
}
