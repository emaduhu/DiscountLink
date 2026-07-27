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
use Illuminate\Foundation\Testing\RefreshDatabase;
use Mockery;
use Tests\TestCase;

class ShopLifecycleTest extends TestCase
{
    use RefreshDatabase;

    public function test_seller_can_soft_delete_own_shop_without_overwriting_product_state(): void
    {
        $seller = $this->seller(1);
        $buyer = User::factory()->create(['role' => 'buyer', 'is_active' => true]);
        $shop = $this->shop($seller);
        $activeProduct = $this->product($shop, ['name' => 'Available before deletion']);
        $inactiveProduct = $this->product($shop, ['name' => 'Seller disabled', 'is_active' => false]);
        Cart::create(['buyer_id' => $buyer->id, 'product_id' => $activeProduct->id, 'quantity' => 1]);
        $order = Order::create([
            'reference' => 'SHOP-DELETE-HISTORY',
            'buyer_id' => $buyer->id,
            'seller_id' => $seller->id,
            'shop_id' => $shop->id,
            'status' => 'paid',
            'delivery_address' => 'Dar es Salaam',
            'subtotal' => 1000,
            'delivery_total' => 0,
            'grand_total' => 1000,
        ]);

        $this->withToken($this->apiToken($seller))
            ->deleteJson("/api/shops/{$shop->id}")
            ->assertOk()
            ->assertJsonPath('message', 'Shop deleted. Its products are no longer available.');

        $this->assertSoftDeleted('shops', ['id' => $shop->id]);
        $this->assertDatabaseHas('shops', ['id' => $shop->id, 'is_active' => false]);
        $this->assertDatabaseHas('products', ['id' => $activeProduct->id, 'is_active' => true, 'stock' => 8]);
        $this->assertDatabaseHas('products', ['id' => $inactiveProduct->id, 'is_active' => false]);
        $this->assertDatabaseMissing('carts', ['product_id' => $activeProduct->id]);
        $this->assertSame($shop->id, $order->fresh()->shop->id);
        $this->assertTrue($order->fresh()->shop->trashed());

        $this->withToken($this->apiToken($buyer))
            ->getJson('/api/products')
            ->assertOk()
            ->assertJsonMissing(['name' => 'Available before deletion']);
        $this->withToken($this->apiToken($buyer))
            ->postJson("/api/cart/{$activeProduct->id}", ['quantity' => 1])
            ->assertUnprocessable();
        $this->withToken($this->apiToken($seller))
            ->deleteJson("/api/shops/{$shop->id}")
            ->assertNotFound();
    }

    public function test_seller_cannot_delete_another_sellers_shop(): void
    {
        $owner = $this->seller(2);
        $otherSeller = $this->seller(3);
        $shop = $this->shop($owner);
        $product = $this->product($shop);

        $this->withToken($this->apiToken($otherSeller))
            ->deleteJson("/api/shops/{$shop->id}")
            ->assertForbidden();

        $this->assertFalse($shop->fresh()->trashed());
        $this->assertTrue($product->fresh()->is_active);
    }

    public function test_seller_can_retry_their_current_unpaid_shop_registration_payment(): void
    {
        $seller = $this->seller(4);
        [$shop, $payment] = $this->registrationPayment($seller);
        $clickPesa = Mockery::mock(ClickPesaService::class);
        $clickPesa->shouldReceive('requestUssdPush')
            ->once()
            ->with(Mockery::on(fn (Payment $candidate) => $candidate->is($payment)
                && $candidate->phone === '255755000004'))
            ->andReturnUsing(function (Payment $candidate): array {
                $candidate->update([
                    'provider_reference' => 'SHOP-RETRY-REFERENCE',
                    'status' => 'processing',
                ]);

                return ['reference' => 'SHOP-RETRY-REFERENCE', 'channel' => 'USSD'];
            });
        $this->app->instance(ClickPesaService::class, $clickPesa);

        $this->withToken($this->apiToken($seller))
            ->postJson("/api/seller/shop-payments/{$payment->id}/ussd-push", [
                'registration_payment_phone' => ' +255 755-000-004 ',
            ])
            ->assertOk()
            ->assertJsonPath('payment.phone', '255755000004')
            ->assertJsonPath('payment.status', 'processing')
            ->assertJsonPath('shop.registration_fee_status', 'processing')
            ->assertJsonPath('shop.is_active', false)
            ->assertJsonPath(
                'message',
                'Shop registration payment request sent to 255755000004. Reference: SHOP-RETRY-REFERENCE. Channel: USSD. Check your phone and approve the USSD prompt.',
            );

        $this->assertDatabaseHas('shops', [
            'id' => $shop->id,
            'is_active' => false,
            'registration_fee_status' => 'processing',
        ]);
        $this->assertDatabaseHas('payments', [
            'id' => $payment->id,
            'phone' => '255755000004',
        ]);
    }

    public function test_shop_payment_retry_rejects_paid_wrong_type_and_unowned_payments(): void
    {
        $seller = $this->seller(5);
        [$shop, $paidPayment] = $this->registrationPayment($seller, ['status' => 'paid']);
        $shop->update(['registration_fee_status' => 'paid']);
        $otherSeller = $this->seller(6);
        [, $otherPayment] = $this->registrationPayment($otherSeller);
        $collectionPayment = Payment::create([
            'user_id' => $seller->id,
            'type' => 'collection',
            'provider' => 'clickpesa',
            'status' => 'failed',
            'amount' => 1000,
            'phone' => $seller->phone,
        ]);
        $clickPesa = Mockery::mock(ClickPesaService::class);
        $clickPesa->shouldNotReceive('requestUssdPush');
        $this->app->instance(ClickPesaService::class, $clickPesa);
        $token = $this->apiToken($seller);

        $this->withToken($token)
            ->postJson("/api/seller/shop-payments/{$paidPayment->id}/ussd-push")
            ->assertUnprocessable();
        $this->withToken($token)
            ->postJson("/api/seller/shop-payments/{$otherPayment->id}/ussd-push")
            ->assertForbidden();
        $this->withToken($token)
            ->postJson("/api/seller/shop-payments/{$collectionPayment->id}/ussd-push")
            ->assertForbidden();
    }

    public function test_deleted_shop_cannot_be_retried_or_reactivated_by_callback(): void
    {
        $seller = $this->seller(7);
        [$shop, $payment] = $this->registrationPayment($seller, [
            'provider_reference' => 'DELETED-SHOP-PAYMENT',
        ]);
        $shop->update(['is_active' => false]);
        $shop->delete();
        $clickPesa = Mockery::mock(ClickPesaService::class);
        $clickPesa->shouldNotReceive('requestUssdPush');
        $this->app->instance(ClickPesaService::class, $clickPesa);

        $this->withToken($this->apiToken($seller))
            ->postJson("/api/seller/shop-payments/{$payment->id}/ussd-push")
            ->assertNotFound();

        (new ClickPesaService)->applyCallback([
            'transactionId' => 'DELETED-SHOP-PAYMENT',
            'status' => 'SUCCESSFUL',
        ]);

        $deletedShop = Shop::withTrashed()->findOrFail($shop->id);
        $this->assertTrue($deletedShop->trashed());
        $this->assertFalse($deletedShop->is_active);
        $this->assertSame('paid', $deletedShop->registration_fee_status);
        $this->assertNotNull($deletedShop->registration_paid_at);
        $this->assertSame('paid', $payment->fresh()->status);
        $this->assertTrue($payment->fresh()->shop->trashed());
    }

    private function seller(int $suffix): User
    {
        return User::factory()->create([
            'role' => 'seller',
            'phone' => sprintf('25570000%04d', $suffix),
            'phone_verified_at' => now(),
            'is_active' => true,
        ]);
    }

    /** @param array<string, mixed> $attributes */
    private function shop(User $seller, array $attributes = []): Shop
    {
        return Shop::create($attributes + [
            'seller_id' => $seller->id,
            'name' => 'Lifecycle Shop',
            'category' => 'Other',
            'address' => 'Dar es Salaam',
            'is_active' => true,
            'registration_fee_amount' => 0,
            'registration_fee_status' => 'waived',
        ]);
    }

    /** @param array<string, mixed> $attributes */
    private function product(Shop $shop, array $attributes = []): Product
    {
        return Product::create($attributes + [
            'shop_id' => $shop->id,
            'seller_id' => $shop->seller_id,
            'name' => 'Lifecycle Product',
            'price' => 1000,
            'delivery_price' => 0,
            'auto_total' => 1000,
            'stock' => 8,
            'is_active' => true,
        ]);
    }

    /**
     * @param  array<string, mixed>  $paymentAttributes
     * @return array{Shop, Payment}
     */
    private function registrationPayment(User $seller, array $paymentAttributes = []): array
    {
        $shop = $this->shop($seller, [
            'is_active' => false,
            'registration_fee_amount' => 2500,
            'registration_fee_status' => 'processing',
        ]);
        $payment = Payment::create($paymentAttributes + [
            'shop_id' => $shop->id,
            'user_id' => $seller->id,
            'type' => 'shop_registration_fee',
            'provider' => 'clickpesa',
            'status' => 'failed',
            'amount' => 2500,
            'phone' => $seller->phone,
        ]);
        $shop->update(['registration_fee_payment_id' => $payment->id]);

        return [$shop->fresh(), $payment];
    }

    private function apiToken(User $user): string
    {
        $token = 'shop-lifecycle-token-'.$user->id;
        ApiToken::firstOrCreate(
            ['token_hash' => hash('sha256', $token)],
            ['user_id' => $user->id, 'name' => 'test'],
        );

        return $token;
    }
}
