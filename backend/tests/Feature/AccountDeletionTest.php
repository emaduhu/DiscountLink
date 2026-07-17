<?php

namespace Tests\Feature;

use App\Models\ApiToken;
use App\Models\User;
use App\Services\ApiTokenService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AccountDeletionTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_soft_delete_account_and_revoke_tokens(): void
    {
        $user = User::factory()->create([
            'is_active' => true,
            'is_available' => true,
            'fcm_token' => 'device-token',
        ]);
        $token = app(ApiTokenService::class)->issue($user);

        $response = $this->withToken($token)->deleteJson('/api/me');

        $response->assertOk()
            ->assertJsonPath('message', 'Account deleted.');

        $this->assertSoftDeleted('users', ['id' => $user->id]);
        $this->assertDatabaseMissing('api_tokens', ['user_id' => $user->id]);

        $deletedUser = User::withTrashed()->findOrFail($user->id);
        $this->assertFalse($deletedUser->is_active);
        $this->assertFalse($deletedUser->is_available);
        $this->assertNull($deletedUser->fcm_token);
    }

    public function test_deleted_account_token_cannot_be_used_again(): void
    {
        $user = User::factory()->create();
        $token = app(ApiTokenService::class)->issue($user);

        $this->withToken($token)->deleteJson('/api/me')->assertOk();

        $this->withToken($token)->getJson('/api/me')
            ->assertUnauthorized()
            ->assertJsonPath('message', 'Invalid or expired bearer token.');
        $this->assertSame(0, ApiToken::where('user_id', $user->id)->count());
    }

    public function test_admin_can_restore_soft_deleted_account(): void
    {
        $admin = User::factory()->create([
            'role' => 'admin',
            'is_active' => true,
        ]);
        $user = User::factory()->create([
            'role' => 'buyer',
            'is_active' => false,
            'is_available' => false,
        ]);
        $user->delete();

        $response = $this->actingAs($admin)->post(route('dashboard.users.restore', $user->id));

        $response->assertRedirect(route('dashboard', ['page' => 'users']));

        $restored = User::findOrFail($user->id);
        $this->assertFalse($restored->trashed());
        $this->assertTrue($restored->is_active);
        $this->assertTrue($restored->is_available);
    }
}
