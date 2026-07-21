<?php

namespace Tests\Feature;

use App\Models\ApiToken;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class FcmTokenOwnershipTest extends TestCase
{
    use RefreshDatabase;

    public function test_authenticated_user_can_claim_and_clear_a_device_token(): void
    {
        $previousOwner = User::factory()->create(['fcm_token' => 'shared-device-token']);
        $user = User::factory()->create(['fcm_token' => null]);
        $token = $this->apiToken($user);

        $this->withToken($token)
            ->postJson('/api/me/fcm-token', ['fcm_token' => 'shared-device-token'])
            ->assertOk()
            ->assertJsonPath('message', 'FCM token updated.');

        $this->assertNull($previousOwner->fresh()->fcm_token);
        $this->assertSame('shared-device-token', $user->fresh()->fcm_token);
        $this->assertSame(1, User::where('fcm_token', 'shared-device-token')->count());

        $this->withToken($token)
            ->postJson('/api/me/fcm-token', ['fcm_token' => null])
            ->assertOk()
            ->assertJsonPath('message', 'FCM token cleared.');

        $this->assertNull($user->fresh()->fcm_token);
    }

    public function test_login_transfers_device_token_from_the_previous_account(): void
    {
        $previousOwner = User::factory()->create(['fcm_token' => 'login-device-token']);
        $user = User::factory()->create([
            'email' => 'new-owner@example.test',
            'password' => 'secret-pass',
            'fcm_token' => null,
        ]);

        $this->postJson('/api/auth/login', [
            'identifier' => $user->email,
            'password' => 'secret-pass',
            'fcm_token' => 'login-device-token',
        ])->assertOk()
            ->assertJsonPath('user.id', $user->id)
            ->assertJsonPath('user.fcm_token', 'login-device-token');

        $this->assertNull($previousOwner->fresh()->fcm_token);
        $this->assertSame('login-device-token', $user->fresh()->fcm_token);
        $this->assertSame(1, User::where('fcm_token', 'login-device-token')->count());
    }

    public function test_fcm_token_uniqueness_remains_case_sensitive(): void
    {
        User::factory()->create(['fcm_token' => 'case-sensitive-token-A']);
        User::factory()->create(['fcm_token' => 'case-sensitive-token-a']);

        $this->assertSame(
            2,
            User::whereIn('fcm_token', [
                'case-sensitive-token-A',
                'case-sensitive-token-a',
            ])->count(),
        );
    }

    private function apiToken(User $user): string
    {
        $plain = 'fcm-owner-token-'.$user->id;
        ApiToken::create([
            'user_id' => $user->id,
            'name' => 'test',
            'token_hash' => hash('sha256', $plain),
        ]);

        return $plain;
    }
}
