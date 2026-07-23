<?php

namespace Tests\Feature;

use App\Models\Payment;
use App\Models\Product;
use App\Models\Shop;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AdminShopRestoreTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_can_search_active_and_deleted_shops_with_owner_and_payment_context(): void
    {
        $admin = User::factory()->create(['role' => 'admin', 'is_active' => true]);
        $activeSeller = User::factory()->create([
            'role' => 'seller',
            'name' => 'Active Shop Owner',
            'email' => 'active-shop-owner@example.test',
        ]);
        $deletedSeller = User::factory()->create([
            'role' => 'seller',
            'name' => 'Archived Shop Owner',
            'email' => 'archived-shop-owner@example.test',
            'phone' => '255700000099',
        ]);

        $activeShop = $this->shopFor($activeSeller, [
            'name' => 'Open Market',
            'registration_fee_status' => 'waived',
        ]);
        $deletedShop = $this->shopFor($deletedSeller, [
            'name' => 'Archived Bazaar',
            'registration_fee_amount' => 2500,
            'registration_fee_status' => 'paid',
            'is_active' => false,
        ]);
        $payment = Payment::create([
            'shop_id' => $deletedShop->id,
            'user_id' => $deletedSeller->id,
            'type' => 'shop_registration_fee',
            'provider' => 'clickpesa',
            'provider_reference' => 'SHOP-PAYMENT-ARCHIVED',
            'status' => 'paid',
            'amount' => 2500,
            'phone' => '255700000099',
        ]);
        $deletedShop->update(['registration_fee_payment_id' => $payment->id]);
        $deletedShop->delete();

        $response = $this->actingAs($admin)->get(route('dashboard', [
            'page' => 'shops',
            'shops_per_page' => 10,
        ]));

        $response->assertOk()
            ->assertSee('Shop Management')
            ->assertSee('Open Market')
            ->assertSee('Archived Bazaar')
            ->assertSee('Archived Shop Owner')
            ->assertSee('SHOP-PAYMENT-ARCHIVED')
            ->assertSee(route('dashboard.shops.restore', $deletedShop->id), false)
            ->assertDontSee(route('dashboard.shops.restore', $activeShop->id), false)
            ->assertSee("document.querySelectorAll('form[method=\"post\"]')", false)
            ->assertSee('Processing…', false)
            ->assertViewHas('shops', fn ($shops) => $shops->total() === 2 && $shops->perPage() === 10);

        $this->actingAs($admin)->get(route('dashboard', [
            'page' => 'shops',
            'shops_q' => 'SHOP-PAYMENT-ARCHIVED',
        ]))
            ->assertOk()
            ->assertSee('Archived Bazaar')
            ->assertDontSee('Open Market')
            ->assertViewHas('shops', fn ($shops) => $shops->total() === 1);

        $this->actingAs($admin)->get(route('dashboard', [
            'page' => 'shops',
            'shops_q' => 'Archived Shop Owner',
        ]))
            ->assertOk()
            ->assertSee('Archived Bazaar')
            ->assertViewHas('shops', fn ($shops) => $shops->total() === 1);
    }

    public function test_admin_can_restore_a_paid_shop_without_reactivating_its_products(): void
    {
        $admin = User::factory()->create(['role' => 'admin', 'is_active' => true]);
        $seller = User::factory()->create(['role' => 'seller']);
        $shop = $this->shopFor($seller, [
            'name' => 'Recoverable Shop',
            'registration_fee_amount' => 2500,
            'registration_fee_status' => 'processing',
            'is_active' => false,
        ]);
        $payment = Payment::create([
            'shop_id' => $shop->id,
            'user_id' => $seller->id,
            'type' => 'shop_registration_fee',
            'provider' => 'clickpesa',
            'status' => 'paid',
            'amount' => 2500,
            'phone' => '255700000077',
        ]);
        $shop->update(['registration_fee_payment_id' => $payment->id]);
        $product = Product::create([
            'shop_id' => $shop->id,
            'seller_id' => $seller->id,
            'name' => 'Inactive Product',
            'price' => 1000,
            'delivery_price' => 0,
            'auto_total' => 1000,
            'stock' => 10,
            'is_active' => false,
        ]);
        $shop->delete();

        $response = $this->actingAs($admin)->post(route('dashboard.shops.restore', $shop->id));

        $response->assertRedirect(route('dashboard', ['page' => 'shops']))
            ->assertSessionHas('status', 'Shop restored and activated.');

        $restored = Shop::findOrFail($shop->id);
        $this->assertFalse($restored->trashed());
        $this->assertTrue($restored->is_active);
        $this->assertSame('paid', $restored->registration_fee_status);
        $this->assertNotNull($restored->registration_paid_at);
        $this->assertFalse($product->fresh()->is_active);

        $this->actingAs($admin)
            ->post(route('dashboard.shops.restore', $shop->id))
            ->assertUnprocessable();
    }

    public function test_restored_unpaid_shop_remains_inactive_and_non_admin_cannot_restore_it(): void
    {
        $admin = User::factory()->create(['role' => 'admin', 'is_active' => true]);
        $seller = User::factory()->create(['role' => 'seller']);
        $shop = $this->shopFor($seller, [
            'name' => 'Pending Payment Shop',
            'registration_fee_status' => 'pending',
            'is_active' => false,
        ]);
        $shop->delete();

        $this->actingAs($seller)
            ->post(route('dashboard.shops.restore', $shop->id))
            ->assertForbidden();
        $this->assertTrue(Shop::withTrashed()->findOrFail($shop->id)->trashed());

        $this->actingAs($admin)
            ->post(route('dashboard.shops.restore', $shop->id))
            ->assertRedirect(route('dashboard', ['page' => 'shops']))
            ->assertSessionHas(
                'status',
                'Shop restored but remains inactive until its registration fee is paid.',
            );

        $restored = Shop::findOrFail($shop->id);
        $this->assertFalse($restored->trashed());
        $this->assertFalse($restored->is_active);
    }

    /** @param array<string, mixed> $attributes */
    private function shopFor(User $seller, array $attributes = []): Shop
    {
        return Shop::create($attributes + [
            'seller_id' => $seller->id,
            'name' => 'Test Shop',
            'category' => 'General',
            'address' => 'Dar es Salaam',
            'is_active' => true,
            'registration_fee_amount' => 0,
            'registration_fee_status' => 'waived',
        ]);
    }
}
