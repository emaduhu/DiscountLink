<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        $this->call(AdminUserSeeder::class);

        if (! app()->isProduction()) {
            User::updateOrCreate(
                ['email' => 'test@example.com'],
                User::factory()->make([
                    'name' => 'Test User',
                    'email' => 'test@example.com',
                ])->toArray(),
            );

            $this->call(SampleFlowSeeder::class);
        }
    }
}
