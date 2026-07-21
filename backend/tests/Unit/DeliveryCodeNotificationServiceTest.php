<?php

namespace Tests\Unit;

use App\Models\Order;
use App\Models\User;
use App\Services\DeliveryCodeNotificationService;
use App\Services\FcmService;
use App\Services\OtpProviderService;
use Mockery;
use RuntimeException;
use Tests\TestCase;

class DeliveryCodeNotificationServiceTest extends TestCase
{
    public function test_it_sends_the_same_delivery_code_to_the_buyers_sms_and_fcm_channels(): void
    {
        $buyer = new User([
            'role' => 'buyer',
            'phone' => '255700000001',
            'fcm_token' => 'buyer-token',
        ]);
        $buyer->id = 7;
        $order = new Order(['reference' => 'DL-TEST-1', 'buyer_id' => $buyer->id]);
        $order->id = 11;

        $sms = Mockery::mock(OtpProviderService::class);
        $sms->shouldReceive('sendMessage')
            ->once()
            ->with('255700000001', 'Your Vigour Deals delivery code for order DL-TEST-1 is 1234. Share it only after receiving your order.')
            ->andReturn('sms-reference');
        $fcm = Mockery::mock(FcmService::class);
        $fcm->shouldReceive('sendToUser')
            ->once()
            ->with(
                Mockery::on(fn (User $recipient) => $recipient->is($buyer)),
                'Your delivery code',
                'Your Vigour Deals delivery code for order DL-TEST-1 is 1234. Share it only after receiving your order.',
                [
                    'type' => 'delivery_code',
                    'order_id' => '11',
                    'reference' => 'DL-TEST-1',
                    'delivery_code' => '1234',
                ],
            )
            ->andReturn(true);

        $result = (new DeliveryCodeNotificationService($sms, $fcm))->send($buyer, $order, '1234');

        $this->assertSame(['sms' => true, 'fcm' => true], $result);
    }

    public function test_provider_failures_do_not_throw_or_expose_internal_order_code_fields(): void
    {
        $buyer = new User(['role' => 'buyer', 'phone' => '255700000001', 'fcm_token' => 'buyer-token']);
        $buyer->id = 7;
        $order = new Order([
            'reference' => 'DL-TEST-2',
            'buyer_id' => $buyer->id,
            'delivery_code_hash' => 'secret-hash',
            'delivery_code_demo' => '5678',
            'delivery_code_encrypted' => 'encrypted-secret',
        ]);
        $order->id = 12;
        $order->setAttribute('plain_delivery_code', '5678');

        $sms = Mockery::mock(OtpProviderService::class);
        $sms->shouldReceive('sendMessage')->once()->andThrow(new RuntimeException('SMS unavailable'));
        $fcm = Mockery::mock(FcmService::class);
        $fcm->shouldReceive('sendToUser')->once()->andThrow(new RuntimeException('FCM unavailable'));

        $result = (new DeliveryCodeNotificationService($sms, $fcm))->send($buyer, $order, '5678');

        $this->assertSame(['sms' => false, 'fcm' => false], $result);
        $this->assertArrayNotHasKey('delivery_code_hash', $order->toArray());
        $this->assertArrayNotHasKey('delivery_code_demo', $order->toArray());
        $this->assertArrayNotHasKey('delivery_code_encrypted', $order->toArray());
        $this->assertArrayNotHasKey('plain_delivery_code', $order->toArray());
    }
}
