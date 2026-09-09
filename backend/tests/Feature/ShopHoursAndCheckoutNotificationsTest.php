<?php

namespace Tests\Feature;

use App\Models\ApiToken;
use App\Models\Cart;
use App\Models\Order;
use App\Models\Payment;
use App\Models\Product;
use App\Models\Shop;
use App\Models\User;
use App\Services\ClickPesaService;
use App\Services\DeliveryCodeNotificationService;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Mockery;
use Tests\TestCase;

class ShopHoursAndCheckoutNotificationsTest extends TestCase
{
    use RefreshDatabase;

    protected function tearDown(): void
    {
        CarbonImmutable::setTestNow();

        parent::tearDown();
    }

    public function test_seller_can_update_shop_hours_without_resubmitting_shop_profile(): void
    {
        $seller = User::factory()->create(['role' => 'seller']);
        $shop = $this->shop($seller);

        $this->withToken($this->apiToken($seller))
            ->putJson("/api/shops/{$shop->id}/hours", [
                'opening_time' => '20:00',
                'closing_time' => '04:00',
                'timezone' => 'Africa/Dar_es_Salaam',
            ])
            ->assertOk()
            ->assertJsonPath('shop.opening_time', '20:00')
            ->assertJsonPath('shop.closing_time', '04:00')
            ->assertJsonPath('shop.timezone', 'Africa/Dar_es_Salaam');

        $this->assertSame('20:00', $shop->fresh()->opening_time);
        $this->assertSame('04:00', $shop->fresh()->closing_time);
    }

    public function test_checkout_sends_delivery_code_to_the_buyer_and_hides_internal_code_fields(): void
    {
        $buyer = User::factory()->create([
            'role' => 'buyer',
            'phone' => '255700000001',
            'phone_verified_at' => now(),
            'address' => 'Buyer address',
            'fcm_token' => 'buyer-fcm-token',
        ]);
        $seller = User::factory()->create(['role' => 'seller']);
        $shop = $this->shop($seller);
        $product = $this->product($seller, $shop);
        Cart::create(['buyer_id' => $buyer->id, 'product_id' => $product->id, 'quantity' => 1]);

        $clickPesa = Mockery::mock(ClickPesaService::class);
        $clickPesa->shouldReceive('requestUssdPush')
            ->once()
            ->with(Mockery::on(fn (Payment $payment) => $payment->user_id === $buyer->id))
            ->andReturn(['reference' => 'checkout-test', 'status' => 'processing']);
        $this->app->instance(ClickPesaService::class, $clickPesa);

        $sentCode = null;
        $notifications = Mockery::mock(DeliveryCodeNotificationService::class);
        $notifications->shouldReceive('send')
            ->once()
            ->withArgs(function (User $recipient, Order $order, string $deliveryCode) use ($buyer, &$sentCode): bool {
                $sentCode = $deliveryCode;

                return $recipient->is($buyer)
                    && $order->buyer_id === $buyer->id
                    && preg_match('/^(?!.*(.).*\\1)\\d{4}$/', $deliveryCode) === 1;
            })
            ->andReturn(['sms' => true, 'fcm' => true]);
        $this->app->instance(DeliveryCodeNotificationService::class, $notifications);

        $response = $this->withToken($this->apiToken($buyer))
            ->postJson('/api/checkout', ['delivery_address' => 'Buyer address'])
            ->assertCreated()
            ->assertJsonPath('delivery_code_notifications.sms', true)
            ->assertJsonPath('delivery_code_notifications.fcm', true)
            ->assertJsonMissingPath('order.delivery_code_hash')
            ->assertJsonMissingPath('order.delivery_code_demo')
            ->assertJsonMissingPath('order.plain_delivery_code');

        $this->assertSame($sentCode, $response->json('delivery_code'));
        $order = Order::firstOrFail();
        $this->assertTrue(Hash::check($sentCode, $order->delivery_code_hash));
        $this->assertSame($sentCode, $order->deliveryCodeForBuyer());
        $this->assertNull($order->delivery_code_demo);
        $this->assertNotNull($order->getRawOriginal('delivery_code_encrypted'));
    }

    public function test_cart_summary_uses_percent_discount_when_discount_price_is_missing(): void
    {
        $buyer = User::factory()->create([
            'role' => 'buyer',
            'phone' => '255700000011',
            'phone_verified_at' => now(),
            'address' => 'Buyer address',
        ]);
        $seller = User::factory()->create(['role' => 'seller']);
        $shop = $this->shop($seller);
        $product = $this->product($seller, $shop);
        $product->update([
            'price' => 1000,
            'discount_price' => null,
            'discount_percent' => 25,
            'delivery_price' => 100,
            'auto_total' => 1100,
        ]);
        Cart::create(['buyer_id' => $buyer->id, 'product_id' => $product->id, 'quantity' => 2]);

        $this->withToken($this->apiToken($buyer))
            ->getJson('/api/cart')
            ->assertOk()
            ->assertJsonPath('summary.subtotal', 1500)
            ->assertJsonPath('summary.delivery_total', 200)
            ->assertJsonPath('summary.grand_total', 1700);
    }

    public function test_buyer_payment_resend_can_use_a_corrected_phone(): void
    {
        $buyer = User::factory()->create([
            'role' => 'buyer',
            'phone' => '255700000012',
            'phone_verified_at' => now(),
            'address' => 'Buyer address',
        ]);
        $payment = Payment::create([
            'user_id' => $buyer->id,
            'type' => 'collection',
            'provider' => 'clickpesa',
            'status' => 'failed',
            'amount' => 1000,
            'phone' => '255700000012',
        ]);

        $clickPesa = Mockery::mock(ClickPesaService::class);
        $clickPesa->shouldReceive('requestUssdPush')
            ->once()
            ->with(Mockery::on(fn (Payment $candidate): bool => $candidate->is($payment)
                && $candidate->phone === '255755000012'))
            ->andReturnUsing(function (Payment $candidate): array {
                $candidate->update([
                    'provider_reference' => 'BUYER-RETRY-REFERENCE',
                    'status' => 'processing',
                ]);

                return ['reference' => 'BUYER-RETRY-REFERENCE', 'channel' => 'USSD'];
            });
        $this->app->instance(ClickPesaService::class, $clickPesa);

        $this->withToken($this->apiToken($buyer))
            ->postJson("/api/payments/{$payment->id}/ussd-push", [
                'payment_phone' => ' +255 755-000-012 ',
            ])
            ->assertOk()
            ->assertJsonPath('payment.phone', '255755000012')
            ->assertJsonPath('payment.status', 'processing')
            ->assertJsonPath(
                'message',
                'Payment request sent to 255755000012. Reference: BUYER-RETRY-REFERENCE. Channel: USSD. Check your phone and approve the USSD prompt.',
            );

        $this->assertSame('255755000012', $payment->fresh()->phone);
    }

    public function test_seller_can_buy_products_using_the_marketplace_flow(): void
    {
        $buyerSeller = User::factory()->create([
            'role' => 'seller',
            'phone' => '255700000022',
            'phone_verified_at' => now(),
            'address' => 'Seller buyer address',
            'fcm_token' => 'seller-buyer-fcm-token',
        ]);
        $shopOwner = User::factory()->create(['role' => 'seller']);
        $shop = $this->shop($shopOwner);
        $product = $this->product($shopOwner, $shop);
        $buyerSellerToken = $this->apiToken($buyerSeller);

        $this->withToken($buyerSellerToken)
            ->postJson("/api/cart/{$product->id}", ['quantity' => 2])
            ->assertCreated()
            ->assertJsonPath('item.buyer_id', $buyerSeller->id)
            ->assertJsonPath('item.product_id', $product->id)
            ->assertJsonPath('item.quantity', 2);

        $this->withToken($buyerSellerToken)
            ->getJson('/api/cart')
            ->assertOk()
            ->assertJsonPath('summary.subtotal', 2000)
            ->assertJsonPath('summary.delivery_total', 400)
            ->assertJsonPath('summary.grand_total', 2400);

        $this->withToken($buyerSellerToken)
            ->postJson("/api/products/{$product->id}/rating", [
                'rating' => 5,
                'comment' => 'Works for sellers buying too.',
            ])
            ->assertOk()
            ->assertJsonPath('product.id', $product->id);
        $this->assertDatabaseHas('product_ratings', [
            'product_id' => $product->id,
            'buyer_id' => $buyerSeller->id,
            'rating' => 5,
        ]);

        $clickPesa = Mockery::mock(ClickPesaService::class);
        $clickPesa->shouldReceive('requestUssdPush')
            ->once()
            ->with(Mockery::on(fn (Payment $payment): bool => $payment->user_id === $buyerSeller->id
                && $payment->type === 'collection'
                && (float) $payment->amount === 2400.0))
            ->andReturn(['reference' => 'seller-buyer-checkout', 'status' => 'processing']);
        $this->app->instance(ClickPesaService::class, $clickPesa);

        $notifications = Mockery::mock(DeliveryCodeNotificationService::class);
        $notifications->shouldReceive('send')
            ->once()
            ->withArgs(fn (User $recipient, Order $order, string $deliveryCode): bool => $recipient->is($buyerSeller)
                && $order->buyer_id === $buyerSeller->id
                && preg_match('/^(?!.*(.).*\\1)\\d{4}$/', $deliveryCode) === 1)
            ->andReturn(['sms' => true, 'fcm' => true]);
        $this->app->instance(DeliveryCodeNotificationService::class, $notifications);

        $this->withToken($buyerSellerToken)
            ->postJson('/api/checkout', ['delivery_address' => 'Seller buyer address'])
            ->assertCreated()
            ->assertJsonPath('order.buyer_id', $buyerSeller->id)
            ->assertJsonPath('order.seller_id', $shopOwner->id)
            ->assertJsonPath('payment.user_id', $buyerSeller->id);

        $this->withToken($buyerSellerToken)
            ->getJson('/api/orders/active')
            ->assertOk()
            ->assertJsonPath('orders.0.buyer_id', $buyerSeller->id)
            ->assertJsonPath('orders.0.shop.id', $shop->id);
    }

    public function test_checkout_is_rejected_while_shop_is_closed(): void
    {
        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-07-21 20:00:00', 'Africa/Dar_es_Salaam'));
        $buyer = User::factory()->create([
            'role' => 'buyer',
            'phone' => '255700000002',
            'phone_verified_at' => now(),
            'address' => 'Buyer address',
        ]);
        $seller = User::factory()->create(['role' => 'seller']);
        $shop = $this->shop($seller, [
            'opening_time' => '09:00',
            'closing_time' => '17:00',
            'timezone' => 'Africa/Dar_es_Salaam',
        ]);
        $product = $this->product($seller, $shop);
        Cart::create(['buyer_id' => $buyer->id, 'product_id' => $product->id, 'quantity' => 1]);

        $clickPesa = Mockery::mock(ClickPesaService::class);
        $clickPesa->shouldNotReceive('requestUssdPush');
        $this->app->instance(ClickPesaService::class, $clickPesa);
        $notifications = Mockery::mock(DeliveryCodeNotificationService::class);
        $notifications->shouldNotReceive('send');
        $this->app->instance(DeliveryCodeNotificationService::class, $notifications);

        $this->withToken($this->apiToken($buyer))
            ->postJson('/api/checkout', ['delivery_address' => 'Buyer address'])
            ->assertStatus(422)
            ->assertJsonPath('message', 'Test Shop is currently closed. It opens at 2026-07-22T09:00:00+03:00.')
            ->assertJsonPath('shop.is_open', false)
            ->assertJsonPath('shop.next_opening_at', '2026-07-22T09:00:00+03:00');

        $this->assertDatabaseCount('orders', 0);
        $this->assertDatabaseCount('payments', 0);
    }

    private function apiToken(User $user): string
    {
        $token = 'test-token-'.$user->id;
        ApiToken::create([
            'user_id' => $user->id,
            'name' => 'test',
            'token_hash' => hash('sha256', $token),
        ]);

        return $token;
    }

    /**
     * @param  array<string, mixed>  $overrides
     */
    private function shop(User $seller, array $overrides = []): Shop
    {
        return Shop::create(array_merge([
            'seller_id' => $seller->id,
            'name' => 'Test Shop',
            'category' => 'Other',
            'categories' => ['Other'],
            'address' => 'Dar es Salaam',
            'is_active' => true,
        ], $overrides));
    }

    private function product(User $seller, Shop $shop): Product
    {
        return Product::create([
            'shop_id' => $shop->id,
            'seller_id' => $seller->id,
            'name' => 'Test Product',
            'price' => 1000,
            'delivery_price' => 200,
            'auto_total' => 1200,
            'stock' => 5,
            'is_active' => true,
        ]);
    }
}
