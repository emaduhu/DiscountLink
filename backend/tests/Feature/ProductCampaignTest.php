<?php

namespace Tests\Feature;

use App\Jobs\DispatchProductCampaign;
use App\Jobs\SendProductCampaignMessage;
use App\Models\ApiToken;
use App\Models\AppSetting;
use App\Models\Product;
use App\Models\ProductCampaign;
use App\Models\Shop;
use App\Models\User;
use App\Services\FcmService;
use App\Services\OtpProviderService;
use App\Services\ProductCampaignService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\Queue;
use Mockery;
use Tests\TestCase;

class ProductCampaignTest extends TestCase
{
    use RefreshDatabase;

    public function test_seller_is_charged_for_an_immutable_sms_audience_and_delivery_waits_for_payment(): void
    {
        Queue::fake();
        Config::set('services.clickpesa.webhook_secret', 'campaign-webhook-secret');
        AppSetting::put('campaign_sms_unit_price', '75.0000');

        [$seller, $product, $token] = $this->sellerProductAndToken([
            'phone' => '255700000001',
            'phone_verified_at' => now(),
        ]);
        User::factory()->create([
            'role' => 'buyer',
            'phone' => '255700000002',
            'phone_verified_at' => now(),
            'is_active' => true,
        ]);
        User::factory()->create([
            'role' => 'buyer',
            'phone' => '255700000003',
            'phone_verified_at' => null,
            'is_active' => true,
        ]);
        User::factory()->create([
            'role' => 'admin',
            'phone' => '255700000004',
            'phone_verified_at' => now(),
            'is_active' => true,
        ]);

        $response = $this->withToken($token)->postJson('/api/seller/campaigns', [
            'product_id' => $product->id,
            'channel' => 'sms',
            'title' => 'Seller controlled title',
            'message' => 'Seller controlled message',
        ]);

        $response->assertStatus(202)
            ->assertJsonPath('campaign.channel', 'sms')
            ->assertJsonPath('campaign.recipient_count', 2)
            ->assertJsonPath('campaign.total_cost', '150.00')
            ->assertJsonPath('payment.amount', '150.00');

        $campaign = ProductCampaign::firstOrFail();
        $this->assertSame($seller->id, $campaign->seller_id);
        $this->assertSame('pending_payment', $campaign->status);
        $this->assertStringStartsWith('Vigour Deals:', $campaign->message);
        $this->assertStringNotContainsString('Seller controlled', $campaign->message);
        $this->assertCount(2, $campaign->deliveries);
        Queue::assertNotPushed(DispatchProductCampaign::class);

        $payment = $campaign->payment;
        $this->postJson('/api/webhooks/clickpesa', $this->signedCallback([
            'transactionId' => $payment->provider_reference,
            'status' => 'SUCCESSFUL',
        ]))->assertOk();

        $this->assertSame('queued', $campaign->fresh()->status);
        $this->assertNotNull($campaign->fresh()->paid_at);
        Queue::assertPushed(DispatchProductCampaign::class, 1);

        // Replayed provider callbacks do not duplicate the campaign dispatch.
        $this->postJson('/api/webhooks/clickpesa', $this->signedCallback([
            'transactionId' => $payment->provider_reference,
            'status' => 'SUCCESSFUL',
        ]))->assertOk();
        Queue::assertPushed(DispatchProductCampaign::class, 1);
    }

    public function test_unsigned_callback_cannot_unlock_a_paid_campaign_when_the_secret_is_missing(): void
    {
        Queue::fake();
        Config::set('services.clickpesa.webhook_secret', null);
        AppSetting::put('campaign_sms_unit_price', '75.0000');

        [, $product, $token] = $this->sellerProductAndToken([
            'phone' => '255700000021',
            'phone_verified_at' => now(),
        ]);

        $this->withToken($token)->postJson('/api/seller/campaigns', [
            'product_id' => $product->id,
            'channel' => 'sms',
        ])->assertStatus(202);

        $campaign = ProductCampaign::firstOrFail();
        $payment = $campaign->payment;

        $this->postJson('/api/webhooks/clickpesa', [
            'transactionId' => $payment->provider_reference,
            'status' => 'SUCCESSFUL',
        ])->assertOk()->assertJsonPath('received', true);

        $this->assertSame('pending_payment', $campaign->fresh()->status);
        $this->assertNull($campaign->fresh()->paid_at);
        $this->assertSame('processing', $payment->fresh()->status);
        Queue::assertNotPushed(DispatchProductCampaign::class);
    }

    public function test_campaign_listing_includes_live_channel_quotes(): void
    {
        AppSetting::put('campaign_sms_unit_price', '50.0000');
        AppSetting::put('campaign_fcm_unit_price', '8.5000');
        [, , $token] = $this->sellerProductAndToken([
            'phone' => '255700000011',
            'phone_verified_at' => now(),
            'fcm_token' => 'seller-device-token',
        ]);
        User::factory()->create([
            'role' => 'buyer',
            'phone' => '255700000012',
            'phone_verified_at' => now(),
            'fcm_token' => 'buyer-device-token',
            'is_active' => true,
        ]);

        $this->withToken($token)->getJson('/api/seller/campaigns')
            ->assertOk()
            ->assertJsonPath('pricing.sms.unit_price', 50)
            ->assertJsonPath('pricing.sms.eligible_recipient_count', 2)
            ->assertJsonPath('pricing.sms.estimated_total', 100)
            ->assertJsonPath('pricing.fcm.unit_price', 8.5)
            ->assertJsonPath('pricing.fcm.eligible_recipient_count', 2)
            ->assertJsonPath('pricing.fcm.estimated_total', 17);
    }

    public function test_free_fcm_campaign_is_queued_and_each_recipient_is_accounted_for(): void
    {
        Queue::fake();
        AppSetting::put('campaign_fcm_unit_price', '0');
        [, $product, $token] = $this->sellerProductAndToken(['fcm_token' => 'seller-token']);
        User::factory()->create([
            'role' => 'buyer',
            'fcm_token' => 'buyer-token',
            'is_active' => true,
        ]);

        $this->withToken($token)->postJson('/api/seller/campaigns', [
            'product_id' => $product->id,
            'channel' => 'fcm',
        ])->assertStatus(202)
            ->assertJsonPath('campaign.status', 'queued')
            ->assertJsonPath('campaign.recipient_count', 2)
            ->assertJsonPath('payment', null);

        $campaign = ProductCampaign::firstOrFail();
        Queue::assertPushed(DispatchProductCampaign::class, 1);

        (new DispatchProductCampaign($campaign->id))->handle(app(ProductCampaignService::class));
        Queue::assertPushed(SendProductCampaignMessage::class, 2);

        $fcm = Mockery::mock(FcmService::class);
        $fcm->shouldReceive('sendToUser')->twice()->andReturnTrue();
        foreach ($campaign->deliveries()->get() as $delivery) {
            (new SendProductCampaignMessage($delivery->id))->handle(
                app(ProductCampaignService::class),
                app(OtpProviderService::class),
                $fcm,
            );
        }

        $campaign->refresh();
        $this->assertSame('completed', $campaign->status);
        $this->assertSame(2, $campaign->sent_count);
        $this->assertSame(0, $campaign->failed_count);
        $this->assertNotNull($campaign->completed_at);
    }

    public function test_new_product_creation_queues_a_free_fcm_campaign_to_all_active_app_users(): void
    {
        Queue::fake();
        AppSetting::put('campaign_fcm_unit_price', '12.5000');

        $seller = User::factory()->create([
            'role' => 'seller',
            'fcm_token' => 'new-product-seller-token',
            'is_active' => true,
        ]);
        $token = 'new-product-seller-token-'.$seller->id;
        ApiToken::create([
            'user_id' => $seller->id,
            'name' => 'test',
            'token_hash' => hash('sha256', $token),
        ]);
        $shop = Shop::create([
            'seller_id' => $seller->id,
            'name' => 'Launch Shop',
            'category' => 'General',
            'address' => 'Dar es Salaam',
            'is_active' => true,
        ]);
        $buyer = User::factory()->create([
            'role' => 'buyer',
            'fcm_token' => 'new-product-buyer-token',
            'is_active' => true,
        ]);
        $deliverer = User::factory()->create([
            'role' => 'deliverer',
            'fcm_token' => 'new-product-deliverer-token',
            'is_active' => true,
        ]);
        User::factory()->create([
            'role' => 'buyer',
            'fcm_token' => null,
            'is_active' => true,
        ]);
        User::factory()->create([
            'role' => 'buyer',
            'fcm_token' => 'new-product-inactive-token',
            'is_active' => false,
        ]);
        User::factory()->create([
            'role' => 'admin',
            'fcm_token' => 'new-product-admin-token',
            'is_active' => true,
        ]);

        $response = $this->withToken($token)->postJson("/api/shops/{$shop->id}/products", [
            'name' => 'Fresh Product',
            'description' => 'Just arrived',
            'price' => 4200,
            'discount_price' => 3900,
            'delivery_price' => 100,
            'stock' => 6,
            'images' => [
                'https://example.com/products/fresh-1.jpg',
                'https://example.com/products/fresh-2.jpg',
                'https://example.com/products/fresh-3.jpg',
            ],
        ]);

        $response->assertCreated();
        $product = Product::findOrFail($response->json('product.id'));
        $campaign = ProductCampaign::where('product_id', $product->id)->firstOrFail();

        $this->assertSame($seller->id, $campaign->seller_id);
        $this->assertStringStartsWith('DLNEW-', $campaign->reference);
        $this->assertSame('fcm', $campaign->channel);
        $this->assertSame('queued', $campaign->status);
        $this->assertSame('0.0000', $campaign->unit_price);
        $this->assertSame('0.00', $campaign->total_cost);
        $this->assertSame(3, $campaign->recipient_count);
        $this->assertNull($campaign->payment_id);
        $this->assertNotNull($campaign->paid_at);
        $this->assertStringStartsWith('New product:', $campaign->title);
        $this->assertStringContainsString('just added Fresh Product', $campaign->message);
        $this->assertEqualsCanonicalizing(
            [$seller->id, $buyer->id, $deliverer->id],
            $campaign->deliveries()->pluck('user_id')->all(),
        );
        Queue::assertPushed(
            DispatchProductCampaign::class,
            fn (DispatchProductCampaign $job): bool => $job->campaignId === $campaign->id,
        );
    }

    public function test_admin_can_configure_campaign_prices_and_see_paid_revenue(): void
    {
        $admin = User::factory()->create(['role' => 'admin', 'is_active' => true]);

        $this->actingAs($admin)->post('/dashboard/campaign-pricing', [
            'campaign_sms_unit_price' => '65.25',
            'campaign_fcm_unit_price' => '7.125',
        ])->assertRedirect(route('dashboard', ['page' => 'settings']));

        $this->assertSame('65.2500', AppSetting::get('campaign_sms_unit_price'));
        $this->assertSame('7.1250', AppSetting::get('campaign_fcm_unit_price'));

        [$seller, $product] = $this->sellerProductAndToken();
        ProductCampaign::create([
            'reference' => 'DLC-REPORT-1',
            'seller_id' => $seller->id,
            'product_id' => $product->id,
            'channel' => 'sms',
            'status' => 'completed',
            'title' => 'Featured deal',
            'message' => 'Static platform message',
            'unit_price' => 50,
            'recipient_count' => 10,
            'total_cost' => 500,
            'sent_count' => 10,
            'paid_at' => now(),
            'completed_at' => now(),
        ]);

        $this->actingAs($admin)->get('/dashboard?page=campaigns')
            ->assertOk()
            ->assertSee('Product Campaign Revenue')
            ->assertSee('DLC-REPORT-1')
            ->assertSee('campaign revenue');
    }

    /** @return array{User, Product, string} */
    private function sellerProductAndToken(array $sellerAttributes = []): array
    {
        $seller = User::factory()->create($sellerAttributes + [
            'role' => 'seller',
            'is_active' => true,
        ]);
        $token = 'seller-token-'.$seller->id;
        ApiToken::create([
            'user_id' => $seller->id,
            'name' => 'test',
            'token_hash' => hash('sha256', $token),
        ]);
        $shop = Shop::create([
            'seller_id' => $seller->id,
            'name' => 'Campaign Shop',
            'category' => 'General',
            'address' => 'Dar es Salaam',
            'is_active' => true,
        ]);
        $product = Product::create([
            'shop_id' => $shop->id,
            'seller_id' => $seller->id,
            'name' => 'Campaign Product',
            'price' => 1200,
            'delivery_price' => 100,
            'auto_total' => 1300,
            'stock' => 20,
            'is_active' => true,
        ]);

        return [$seller, $product, $token];
    }

    /** @param array<string, mixed> $payload */
    private function signedCallback(array $payload): array
    {
        $payload['checksumMethod'] = 'canonical';
        $checksumPayload = $payload;
        unset($checksumPayload['checksumMethod']);
        ksort($checksumPayload);
        $payload['checksum'] = hash_hmac(
            'sha256',
            json_encode($checksumPayload, JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR),
            'campaign-webhook-secret',
        );

        return $payload;
    }
}
