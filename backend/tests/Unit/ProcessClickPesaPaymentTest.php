<?php

namespace Tests\Unit;

use App\Jobs\ProcessClickPesaPayment;
use App\Models\Payment;
use App\Services\ClickPesaService;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Queue;
use Tests\TestCase;

class ProcessClickPesaPaymentTest extends TestCase
{
    use DatabaseMigrations;

    protected function tearDown(): void
    {
        app()->detectEnvironment(fn () => 'testing');

        parent::tearDown();
    }

    public function test_it_queues_ussd_push_payments_on_the_payments_queue(): void
    {
        Queue::fake();

        $payment = Payment::forceCreate([
            'type' => 'collection',
            'status' => 'pending',
            'amount' => 1500,
            'phone' => '+255700000001',
        ]);

        ProcessClickPesaPayment::queueUssdPush($payment);

        $this->assertSame('queued', $payment->fresh()->status);
        $this->assertSame('ussd_push', $payment->fresh()->payload['queued_operation']);

        Queue::assertPushedOn('payments', ProcessClickPesaPayment::class);
    }

    public function test_it_processes_a_queued_ussd_push(): void
    {
        app()->detectEnvironment(fn () => 'production');
        Config::set('services.clickpesa.client_id', 'client-id');
        Config::set('services.clickpesa.api_key', 'api-key');
        Config::set('services.clickpesa.base_url', 'https://api.clickpesa.test');
        Cache::put('clickpesa.jwt.'.sha1('client-id'), 'jwt-token');

        Http::fake([
            'api.clickpesa.test/third-parties/payments/preview-ussd-push-request' => Http::response(['status' => 'previewed']),
            'api.clickpesa.test/third-parties/payments/initiate-ussd-push-request' => Http::response([
                'id' => 'txn-queued-1',
                'status' => 'PENDING',
            ]),
        ]);

        $payment = Payment::forceCreate([
            'id' => 52,
            'type' => 'collection',
            'status' => 'queued',
            'amount' => 1500,
            'phone' => '+255700000001',
            'payload' => ['queued_operation' => 'ussd_push'],
        ]);

        app(ProcessClickPesaPayment::class, [
            'paymentId' => $payment->id,
            'operation' => 'ussd_push',
        ])->handle(app(ClickPesaService::class));

        $payment->refresh();

        $this->assertSame('processing', $payment->status);
        $this->assertSame('txn-queued-1', $payment->provider_reference);
        $this->assertSame('DLPAY0000000052', $payment->payload['orderReference']);
    }
}
