<?php

namespace Tests\Feature;

use App\Models\ApiToken;
use App\Models\AppSetting;
use App\Models\Payment;
use App\Models\User;
use App\Services\ClickPesaService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Mockery;
use Tests\TestCase;

class ShopRegistrationPaymentPhoneTest extends TestCase
{
    use RefreshDatabase;

    public function test_seller_can_use_a_normalized_payment_phone_without_changing_their_account_phone(): void
    {
        AppSetting::put('shop_registration_fee_amount', '2500.00');
        $seller = User::factory()->create([
            'role' => 'seller',
            'phone' => '255700000001',
            'phone_verified_at' => now(),
            'address' => 'Seller address',
        ]);

        $clickPesa = Mockery::mock(ClickPesaService::class);
        $clickPesa->shouldReceive('requestUssdPush')
            ->once()
            ->with(Mockery::on(fn (Payment $payment): bool => $payment->phone === '255754123456'
                && $payment->user_id === $seller->id
                && $payment->type === 'shop_registration_fee'))
            ->andReturn(['reference' => 'shop-registration-test', 'status' => 'processing']);
        $this->app->instance(ClickPesaService::class, $clickPesa);

        $this->withToken($this->apiToken($seller))
            ->postJson('/api/shops', [
                'name' => 'Payment Phone Shop',
                'categories' => ['Other'],
                'address' => 'Dar es Salaam',
                'registration_payment_phone' => ' +255 754-123-456 ',
            ])
            ->assertStatus(202)
            ->assertJsonPath('payment.phone', '255754123456');

        $this->assertDatabaseHas('payments', [
            'user_id' => $seller->id,
            'type' => 'shop_registration_fee',
            'phone' => '255754123456',
        ]);
        $this->assertSame('255700000001', $seller->fresh()->phone);
    }

    public function test_invalid_registration_payment_phone_is_rejected_before_shop_creation(): void
    {
        AppSetting::put('shop_registration_fee_amount', '2500.00');
        $seller = User::factory()->create([
            'role' => 'seller',
            'phone' => '255700000001',
            'phone_verified_at' => now(),
            'address' => 'Seller address',
        ]);

        $clickPesa = Mockery::mock(ClickPesaService::class);
        $clickPesa->shouldNotReceive('requestUssdPush');
        $this->app->instance(ClickPesaService::class, $clickPesa);

        $this->withToken($this->apiToken($seller))
            ->postJson('/api/shops', [
                'name' => 'Invalid Payment Phone Shop',
                'categories' => ['Other'],
                'address' => 'Dar es Salaam',
                'registration_payment_phone' => '+255 754-ABC-456',
            ])
            ->assertStatus(422)
            ->assertJsonValidationErrors('registration_payment_phone');

        $this->assertDatabaseCount('shops', 0);
        $this->assertDatabaseCount('payments', 0);
        $this->assertSame('255700000001', $seller->fresh()->phone);
    }

    private function apiToken(User $user): string
    {
        $token = 'shop-payment-phone-token-'.$user->id;
        ApiToken::create([
            'user_id' => $user->id,
            'name' => 'test',
            'token_hash' => hash('sha256', $token),
        ]);

        return $token;
    }
}
