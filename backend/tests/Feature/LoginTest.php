<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class LoginTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_login_with_normalized_email_identifier(): void
    {
        User::factory()->create([
            'email' => 'buyer@example.com',
            'password' => 'password',
        ]);

        $this->postJson('/api/auth/login', [
            'identifier' => ' BUYER@example.com ',
            'password' => 'password',
        ])
            ->assertOk()
            ->assertJsonPath('user.email', 'buyer@example.com');
    }

    public function test_user_can_login_with_formatted_phone_identifier(): void
    {
        User::factory()->create([
            'email' => 'phone-buyer@example.com',
            'phone' => '255700000001',
            'password' => 'password',
        ]);

        $this->postJson('/api/auth/login', [
            'identifier' => '+255 700 000 001',
            'password' => 'password',
        ])
            ->assertOk()
            ->assertJsonPath('user.phone', '255700000001');
    }
}
