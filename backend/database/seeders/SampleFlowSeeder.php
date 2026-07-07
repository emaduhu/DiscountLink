<?php

namespace Database\Seeders;

use App\Models\Product;
use App\Models\Shop;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class SampleFlowSeeder extends Seeder
{
    public function run(): void
    {
        $password = Hash::make('password');

        $seller = User::updateOrCreate(
            ['email' => 'seller@discountlink.local'],
            [
                'role' => 'seller',
                'name' => 'Demo Seller',
                'username' => 'demo_seller',
                'google_id' => sha1('seller@discountlink.local'),
                'password' => $password,
                'phone' => '255700000002',
                'phone_verified_at' => now(),
                'email_verified_at' => now(),
                'address' => 'Mikocheni, Dar es Salaam',
                'latitude' => -6.7581000,
                'longitude' => 39.2302000,
                'is_active' => true,
            ],
        );

        User::updateOrCreate(
            ['email' => 'buyer@discountlink.local'],
            [
                'role' => 'buyer',
                'name' => 'Demo Buyer',
                'username' => 'demo_buyer',
                'google_id' => sha1('buyer@discountlink.local'),
                'password' => $password,
                'phone' => '255700000001',
                'phone_verified_at' => now(),
                'email_verified_at' => now(),
                'address' => 'Masaki, Dar es Salaam',
                'latitude' => -6.7467000,
                'longitude' => 39.2820000,
                'is_active' => true,
            ],
        );

        User::updateOrCreate(
            ['email' => 'deliverer@discountlink.local'],
            [
                'role' => 'deliverer',
                'name' => 'Demo Deliverer',
                'username' => 'demo_deliverer',
                'google_id' => sha1('deliverer@discountlink.local'),
                'password' => $password,
                'phone' => '255700000003',
                'phone_verified_at' => now(),
                'email_verified_at' => now(),
                'address' => 'Kinondoni, Dar es Salaam',
                'latitude' => -6.7754000,
                'longitude' => 39.2419000,
                'is_active' => true,
            ],
        );

        $shop = Shop::updateOrCreate(
            ['seller_id' => $seller->id, 'name' => 'Demo Deals Store'],
            [
                'category' => 'Electronics',
                'address' => 'Mikocheni, Dar es Salaam',
                'latitude' => -6.7581000,
                'longitude' => 39.2302000,
                'is_active' => true,
            ],
        );

        $this->product($shop, $seller, [
            'name' => 'Wireless Earbuds',
            'description' => 'Compact Bluetooth earbuds for testing checkout and delivery.',
            'price' => 85000,
            'discount_percent' => 20,
            'delivery_price' => 5000,
            'stock' => 25,
        ]);

        $this->product($shop, $seller, [
            'name' => 'Smart Watch',
            'description' => 'Fitness watch sample product with a delivery fee.',
            'price' => 120000,
            'discount_percent' => 15,
            'delivery_price' => 7000,
            'stock' => 15,
        ]);
    }

    private function product(Shop $shop, User $seller, array $data): void
    {
        $discountPrice = round($data['price'] * (1 - ($data['discount_percent'] / 100)), 2);

        Product::updateOrCreate(
            ['shop_id' => $shop->id, 'name' => $data['name']],
            $data + [
                'seller_id' => $seller->id,
                'discount_price' => $discountPrice,
                'auto_total' => $discountPrice + $data['delivery_price'],
                'images' => [],
                'is_active' => true,
            ],
        );
    }
}
