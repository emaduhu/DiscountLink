<?php

namespace Tests\Unit;

use App\Services\ClickPesaService;
use Illuminate\Support\Facades\Config;
use Tests\TestCase;

class ClickPesaWebhookChecksumTest extends TestCase
{
    public function test_it_validates_recursively_canonicalized_clickpesa_webhook_checksums(): void
    {
        Config::set('services.clickpesa.webhook_secret', 'checksum-secret');
        $payload = [
            'event' => 'PAYMENT RECEIVED',
            'data' => [
                'status' => 'SUCCESS',
                'orderReference' => 'DLCAMP0000000001',
                'customer' => ['phone' => '255700000001', 'name' => 'Buyer'],
            ],
            'checksumMethod' => 'canonical',
        ];
        $canonical = [
            'data' => [
                'customer' => ['name' => 'Buyer', 'phone' => '255700000001'],
                'orderReference' => 'DLCAMP0000000001',
                'status' => 'SUCCESS',
            ],
            'event' => 'PAYMENT RECEIVED',
        ];
        $payload['checksum'] = hash_hmac(
            'sha256',
            json_encode($canonical, JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR),
            'checksum-secret',
        );

        $this->assertTrue(app(ClickPesaService::class)->hasValidWebhookChecksum($payload));

        $payload['data']['status'] = 'FAILED';
        $this->assertFalse(app(ClickPesaService::class)->hasValidWebhookChecksum($payload));
    }

    public function test_it_keeps_webhooks_compatible_when_checksum_is_not_configured(): void
    {
        Config::set('services.clickpesa.webhook_secret', null);

        $this->assertTrue(app(ClickPesaService::class)->hasValidWebhookChecksum(['status' => 'SUCCESS']));
    }
}
