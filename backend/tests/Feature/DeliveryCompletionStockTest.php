<?php

namespace Tests\Feature;

use App\Jobs\ProcessClickPesaPayment;
use App\Models\ApiToken;
use App\Models\DeliveryAssignment;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Product;
use App\Models\Shop;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Queue;
use Tests\TestCase;

class DeliveryCompletionStockTest extends TestCase
{
    use RefreshDatabase;

    public function test_product_stock_is_reduced_when_delivery_is_completed(): void
    {
        Queue::fake();

        $seller = User::factory()->create([
            'role' => 'seller',
            'phone' => '+255700000001',
            'phone_verified_at' => now(),
        ]);
        $buyer = User::factory()->create(['role' => 'buyer']);
        $deliverer = User::factory()->create([
            'role' => 'deliverer',
            'phone' => '+255700000002',
            'phone_verified_at' => now(),
        ]);
        $token = 'deliverer-token';
        ApiToken::create([
            'user_id' => $deliverer->id,
            'name' => 'test',
            'token_hash' => hash('sha256', $token),
        ]);

        $shop = Shop::create([
            'seller_id' => $seller->id,
            'name' => 'Test Shop',
            'category' => 'General',
            'address' => 'Dar es Salaam',
        ]);
        $product = Product::create([
            'shop_id' => $shop->id,
            'seller_id' => $seller->id,
            'name' => 'Test Product',
            'price' => 1000,
            'delivery_price' => 200,
            'auto_total' => 1200,
            'stock' => 5,
        ]);
        $order = Order::create([
            'reference' => 'DL-STOCK-1',
            'buyer_id' => $buyer->id,
            'seller_id' => $seller->id,
            'shop_id' => $shop->id,
            'status' => 'out_for_delivery',
            'delivery_address' => 'Buyer Address',
            'subtotal' => 3000,
            'delivery_total' => 600,
            'grand_total' => 3600,
            'delivery_code_hash' => Hash::make('1234'),
        ]);
        OrderItem::create([
            'order_id' => $order->id,
            'product_id' => $product->id,
            'name' => $product->name,
            'quantity' => 3,
            'unit_price' => 1000,
            'delivery_price' => 200,
            'line_total' => 3600,
        ]);
        $assignment = DeliveryAssignment::create([
            'order_id' => $order->id,
            'deliverer_id' => $deliverer->id,
            'status' => 'accepted',
            'accepted_at' => now(),
        ]);

        $this->withToken($token)
            ->postJson("/api/deliveries/{$assignment->id}/complete", ['delivery_code' => '1234'])
            ->assertOk()
            ->assertJsonPath('message', 'Delivery code confirmed. Seller and delivery payments have been queued.');

        $this->assertSame(2, $product->fresh()->stock);
        $this->assertSame('delivered', $order->fresh()->status);
        $this->assertSame('completed', $assignment->fresh()->status);
        Queue::assertPushed(ProcessClickPesaPayment::class, 2);
    }
}
