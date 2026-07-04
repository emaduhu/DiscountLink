<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;

class AdminUserSeeder extends Seeder
{
    public function run(): void
    {
        $email = config('services.discountlink.admin_email', 'admin@dl.vigourtech.net');
        $password = config('services.discountlink.admin_password');

        if (! $password) {
            return;
        }

        User::updateOrCreate(
            ['email' => $email],
            [
                'role' => 'admin',
                'name' => 'DiscountLink Admin',
                'password' => $password,
                'email_verified_at' => now(),
                'is_active' => true,
            ],
        );
    }
}
