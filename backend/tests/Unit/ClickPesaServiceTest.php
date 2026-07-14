<?php

namespace Tests\Unit;

use App\Models\Payment;
use App\Services\ClickPesaService;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class ClickPesaServiceTest extends TestCase
{
    use DatabaseMigrations;

    public function test_it_generates_token_previews_and_initiates_ussd_push(): void
    {
        app()->detectEnvironment(fn () => 'production');
        Config::set('services.clickpesa.client_id', 'client-id');
        Config::set('services.clickpesa.api_key', 'api-key');
        Config::set('services.clickpesa.base_url', 'https://api.clickpesa.test');
        Cache::put('clickpesa.jwt.'.sha1('client-id'), 'jwt-token');

        Http::fake([
            'api.clickpesa.test/third-parties/payments/preview-ussd-push-request' => Http::response(['status' => 'previewed']),
            'api.clickpesa.test/third-parties/payments/initiate-ussd-push-request' => Http::response([
                'id' => 'txn-1',
                'status' => 'PENDING',
            ]),
        ]);

        $payment = Payment::forceCreate([
            'id' => 25,
            'type' => 'collection',
            'status' => 'pending',
            'amount' => 1500,
            'phone' => '+255 700-000-001',
        ]);

        $result = app(ClickPesaService::class)->requestUssdPush($payment);

        $this->assertSame('txn-1', $result['reference']);
        $this->assertSame('DLPAY0000000025', $result['orderReference']);
        $this->assertSame('processing', $result['status']);

        Http::assertSent(fn ($request) => $request->url() === 'https://api.clickpesa.test/third-parties/payments/initiate-ussd-push-request'
            && $request->hasHeader('Authorization', 'Bearer jwt-token')
            && $request['amount'] === '1500.00'
            && $request['currency'] === 'TZS'
            && $request['orderReference'] === 'DLPAY0000000025'
            && $request['phoneNumber'] === '255700000001');
    }
}
