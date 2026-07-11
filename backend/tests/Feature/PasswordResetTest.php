<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class PasswordResetTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_reset_password_with_normalized_email_and_pasted_code(): void
    {
        Config::set('services.discountlink.show_verification_codes', true);

        $user = User::factory()->create([
            'email' => 'buyer@example.com',
            'password' => 'old-password',
        ]);

        $forgotResponse = $this->postJson('/api/auth/password/forgot', [
            'email' => ' buyer@example.com ',
        ]);

        $forgotResponse->assertOk();
        $code = $forgotResponse->json('reset_code');
        $this->assertIsString($code);

        $resetResponse = $this->postJson('/api/auth/password/reset', [
            'email' => ' BUYER@EXAMPLE.COM ',
            'code' => substr($code, 0, 3).' '.substr($code, 3),
            'password' => 'new-password',
            'password_confirmation' => 'new-password',
        ]);

        $resetResponse->assertOk()
            ->assertJsonPath('message', 'Password reset successful. You can now sign in.');

        $this->assertTrue(Hash::check('new-password', $user->fresh()->password));
    }
}
