<?php

namespace App\Services;

use App\Models\AppSetting;
use Illuminate\Support\Facades\Hash;

class OtpProviderService
{
    public function __construct(
        private readonly BeemOtpService $beem,
        private readonly InfobipOtpService $infobip,
    ) {}

    public function activeProvider(): string
    {
        return AppSetting::get('otp_provider', config('services.otp.provider', 'beem')) ?: 'beem';
    }

    public function send(string $phone, string $code): ?string
    {
        return match ($this->activeProvider()) {
            'infobip' => $this->infobip->send($phone, $code),
            'firebase' => 'firebase-client',
            default => $this->beem->send($phone, $code),
        };
    }

    public function sendMessage(string $phone, string $message): ?string
    {
        return match ($this->activeProvider()) {
            'infobip' => $this->infobip->sendMessage($phone, $message),
            default => $this->beem->sendMessage($phone, $message),
        };
    }

    public function shouldCreateBackendOtp(): bool
    {
        return $this->activeProvider() !== 'firebase';
    }

    public function hashCode(string $code): string
    {
        return Hash::make($code);
    }
}
