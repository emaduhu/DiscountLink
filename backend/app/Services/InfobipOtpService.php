<?php

namespace App\Services;

use App\Models\AppSetting;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class InfobipOtpService
{
    public function send(string $phone, string $code): ?string
    {
        if (!config('services.infobip.api_key') || app()->environment('local')) {
            Log::info('DiscountLink Infobip OTP', ['phone' => $phone, 'code' => $code]);
            return 'local-infobip-log';
        }

        $senderId = AppSetting::get('infobip_sender_id', config('services.infobip.sender_id'));
        $baseUrl = AppSetting::get('infobip_base_url', config('services.infobip.base_url'));

        $response = Http::withHeaders([
            'Authorization' => 'App '.config('services.infobip.api_key'),
        ])
            ->acceptJson()
            ->post(rtrim($baseUrl, '/').'/sms/2/text/advanced', [
                'messages' => [[
                    'from' => $senderId,
                    'destinations' => [['to' => $phone]],
                    'text' => "Your DiscountLink verification code is {$code}.",
                ]],
            ]);

        $response->throw();

        return (string) data_get($response->json(), 'messages.0.messageId');
    }
}
