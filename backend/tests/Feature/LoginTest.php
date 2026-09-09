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

    public function test_user_can_login_with_local_phone_identifier(): void
    {
        User::factory()->create([
            'email' => 'local-phone-buyer@example.com',
            'phone' => '255700000002',
            'password' => 'password',
        ]);

        $this->postJson('/api/auth/login', [
            'identifier' => '0700 000 002',
            'password' => 'password',
        ])
            ->assertOk()
            ->assertJsonPath('user.phone', '255700000002');
    }

    public function test_existing_google_user_with_password_can_login_with_email_or_phone(): void
    {
        User::factory()->create([
            'email' => 'existing-google@example.com',
            'phone' => '255700000003',
            'google_id' => 'google-existing-user',
            'password' => 'google-secret',
        ]);

        $this->postJson('/api/auth/login', [
            'identifier' => ' EXISTING-GOOGLE@example.com ',
            'password' => 'google-secret',
        ])
            ->assertOk()
            ->assertJsonPath('user.email', 'existing-google@example.com');

        $this->postJson('/api/auth/login', [
            'identifier' => '0700 000 003',
            'password' => 'google-secret',
        ])
            ->assertOk()
            ->assertJsonPath('user.phone', '255700000003');
    }

    public function test_existing_google_user_without_password_gets_password_setup_message(): void
    {
        User::factory()->create([
            'email' => 'passwordless-google@example.com',
            'phone' => '255700000004',
            'google_id' => 'google-passwordless-user',
            'password' => null,
        ]);

        $this->postJson('/api/auth/login', [
            'identifier' => 'passwordless-google@example.com',
            'password' => 'anything',
        ])
            ->assertUnprocessable()
            ->assertJsonPath('code', 'password_setup_required')
            ->assertJsonPath('message', 'This Google account does not have a password yet. Use Forgot password to create one, or sign in with Google and create a password.');
    }
}
