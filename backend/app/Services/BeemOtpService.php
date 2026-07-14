<?php

namespace App\Services;

use App\Models\AppSetting;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class BeemOtpService
{
    public function send(string $phone, string $code): ?string
    {
        return $this->sendMessage($phone, "Your DiscountLink verification code is {$code}.");
    }

    public function sendMessage(string $phone, string $message): ?string
    {
        if (!config('services.beem.api_key') || app()->environment('local')) {
            Log::info('DiscountLink SMS', ['phone' => $phone, 'message' => $message]);
            return 'local-log';
        }

        $senderId = AppSetting::get('beem_sender_id', config('services.beem.sender_id'));
        $baseUrl = AppSetting::get('beem_base_url', config('services.beem.base_url'));

        $response = Http::withBasicAuth(config('services.beem.api_key'), config('services.beem.secret_key'))
            ->timeout(15)
            ->acceptJson()
            ->post(rtrim($baseUrl, '/').'/sms/v1/send', [
                'source_addr' => $senderId,
                'encoding' => 0,
                'schedule_time' => '',
                'message' => $message,
                'recipients' => [['recipient_id' => 1, 'dest_addr' => $phone]],
            ]);

        $response->throw();
        $requestId = (string) data_get($response->json(), 'request_id');
        Log::info('DiscountLink Beem SMS accepted.', [
            'phone' => $phone,
            'sender_id' => $senderId,
            'request_id' => $requestId,
        ]);

        return $requestId;
    }
}
