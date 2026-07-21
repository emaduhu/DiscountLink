<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Fillable([
    'reference', 'seller_id', 'product_id', 'payment_id', 'channel', 'status', 'title', 'message',
    'unit_price', 'recipient_count', 'total_cost', 'sent_count', 'failed_count', 'paid_at', 'started_at', 'completed_at',
])]
class ProductCampaign extends Model
{
    protected function casts(): array
    {
        return [
            'unit_price' => 'decimal:4',
            'total_cost' => 'decimal:2',
            'paid_at' => 'datetime',
            'started_at' => 'datetime',
            'completed_at' => 'datetime',
        ];
    }

    public function seller(): BelongsTo
    {
        return $this->belongsTo(User::class, 'seller_id');
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }

    public function payment(): BelongsTo
    {
        return $this->belongsTo(Payment::class);
    }

    public function deliveries(): HasMany
    {
        return $this->hasMany(ProductCampaignDelivery::class);
    }
}
