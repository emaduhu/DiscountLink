<?php

namespace Tests\Feature;

use App\Models\User;
use App\Services\ApiTokenService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class PhoneOtpTest extends TestCase
{
    use RefreshDatabase;

    public function test_beem_otp_uses_vigourtech_sender_and_user_can_verify_phone(): void
    {
        Config::set('services.beem.api_key', 'test-api-key');
        Config::set('services.beem.secret_key', 'test-secret-key');
        Config::set('services.beem.sender_id', 'VIGOURTECH');
        Config::set('services.discountlink.show_verification_codes', true);

        Http::fake([
            'https://apisms.beem.africa/sms/v1/send' => Http::response(['request_id' => 'test-request'], 200),
        ]);

        $user = User::factory()->create([
            'role' => 'buyer',
            'phone' => '255700000001',
            'phone_verified_at' => null,
            'is_active' => true,
        ]);
        $token = app(ApiTokenService::class)->issue($user);

        $requestResponse = $this
            ->withToken($token)
            ->postJson('/api/otp/request', ['phone' => '255 700-000001']);

        $requestResponse
            ->assertOk()
            ->assertJsonPath('provider', 'beem')
            ->assertJsonPath('phone_otp_sent', true);

        Http::assertSent(function ($request) {
            return $request->url() === 'https://apisms.beem.africa/sms/v1/send'
                && $request['source_addr'] === 'VIGOURTECH'
                && $request['recipients'][0]['dest_addr'] === '255700000001';
        });

        $code = $requestResponse->json('phone_code');
        $this->assertIsString($code);

        $verifyResponse = $this
            ->withToken($token)
            ->postJson('/api/otp/verify', [
                'phone' => '255 700-000001',
                'code' => substr($code, 0, 3).' '.substr($code, 3),
            ]);

        $verifyResponse
            ->assertOk()
            ->assertJsonPath('message', 'Phone verified.');

        $this->assertNotNull($user->fresh()->phone_verified_at);
    }
}
