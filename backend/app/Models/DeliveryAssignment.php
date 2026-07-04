<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['order_id', 'deliverer_id', 'status', 'accepted_at', 'completed_at'])]
class DeliveryAssignment extends Model
{
    protected function casts(): array
    {
        return ['accepted_at' => 'datetime', 'completed_at' => 'datetime'];
    }

    public function order(): BelongsTo { return $this->belongsTo(Order::class); }
    public function deliverer(): BelongsTo { return $this->belongsTo(User::class, 'deliverer_id'); }
}
