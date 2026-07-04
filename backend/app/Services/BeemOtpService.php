<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class BeemOtpService
{
    public function send(string $phone, string $code): ?string
    {
        if (!config('services.beem.api_key') || app()->environment('local')) {
            Log::info('DiscountLink OTP', ['phone' => $phone, 'code' => $code]);
            return 'local-log';
        }

        $response = Http::withBasicAuth(config('services.beem.api_key'), config('services.beem.secret_key'))
            ->acceptJson()
            ->post(rtrim(config('services.beem.base_url'), '/').'/sms/v1/send', [
                'source_addr' => config('services.beem.sender_id'),
                'encoding' => 0,
                'schedule_time' => '',
                'message' => "Your DiscountLink verification code is {$code}.",
                'recipients' => [['recipient_id' => 1, 'dest_addr' => $phone]],
            ]);

        $response->throw();
        return (string) data_get($response->json(), 'request_id');
    }
}
