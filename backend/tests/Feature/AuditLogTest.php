<?php

namespace Tests\Feature;

use App\Models\AuditLog;
use App\Models\User;
use App\Services\ApiTokenService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuditLogTest extends TestCase
{
    use RefreshDatabase;

    public function test_authenticated_mutating_api_request_is_stored_in_audit_logs(): void
    {
        $user = User::factory()->create([
            'name' => 'Original Name',
            'role' => 'buyer',
            'is_active' => true,
        ]);
        $token = app(ApiTokenService::class)->issue($user);

        $this->withToken($token)
            ->putJson('/api/me', [
                'name' => 'Updated Buyer',
            ])
            ->assertOk()
            ->assertJsonPath('user.name', 'Updated Buyer');

        $auditLog = AuditLog::query()
            ->where('event', 'http.request')
            ->where('method', 'PUT')
            ->where('path', 'api/me')
            ->latest('id')
            ->firstOrFail();

        $this->assertSame($user->id, $auditLog->actor_id);
        $this->assertSame('buyer', $auditLog->actor_role);
        $this->assertSame(200, $auditLog->response_status);
        $this->assertSame('Updated Buyer', data_get($auditLog->metadata, 'request_payload.name'));
    }

    public function test_model_changes_are_audited_with_sensitive_values_masked(): void
    {
        $user = User::factory()->create([
            'name' => 'Sensitive User',
            'password' => 'initial-password',
        ]);

        $created = AuditLog::query()
            ->where('event', 'model.created')
            ->where('auditable_type', User::class)
            ->where('auditable_id', $user->id)
            ->latest('id')
            ->firstOrFail();

        $this->assertSame('[redacted]', data_get($created->new_values, 'password'));

        $user->update([
            'name' => 'Renamed User',
            'password' => 'changed-password',
        ]);

        $updated = AuditLog::query()
            ->where('event', 'model.updated')
            ->where('auditable_type', User::class)
            ->where('auditable_id', $user->id)
            ->latest('id')
            ->firstOrFail();

        $this->assertSame('Sensitive User', data_get($updated->old_values, 'name'));
        $this->assertSame('Renamed User', data_get($updated->new_values, 'name'));
        $this->assertSame('[redacted]', data_get($updated->old_values, 'password'));
        $this->assertSame('[redacted]', data_get($updated->new_values, 'password'));
    }
}
