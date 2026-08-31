<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable([
    'request_id',
    'source',
    'event',
    'action',
    'actor_type',
    'actor_id',
    'actor_role',
    'actor_name',
    'actor_email',
    'auditable_type',
    'auditable_id',
    'method',
    'route_name',
    'path',
    'url',
    'ip_address',
    'user_agent',
    'response_status',
    'duration_ms',
    'metadata',
    'old_values',
    'new_values',
    'created_at',
])]
class AuditLog extends Model
{
    public $timestamps = false;

    protected function casts(): array
    {
        return [
            'actor_id' => 'integer',
            'auditable_id' => 'integer',
            'response_status' => 'integer',
            'duration_ms' => 'integer',
            'metadata' => 'array',
            'old_values' => 'array',
            'new_values' => 'array',
            'created_at' => 'datetime',
        ];
    }

    public function actor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'actor_id')->withTrashed();
    }
}
