<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['seller_id', 'name', 'phone', 'message', 'provider_reference', 'sent_at'])]
class DelivererInvitation extends Model
{
    protected function casts(): array
    {
        return ['sent_at' => 'datetime'];
    }

    public function seller(): BelongsTo
    {
        return $this->belongsTo(User::class, 'seller_id');
    }
}
