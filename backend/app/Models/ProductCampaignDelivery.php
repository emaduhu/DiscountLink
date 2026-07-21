<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable([
    'product_campaign_id', 'user_id', 'destination', 'status', 'provider_reference',
    'attempt_count', 'last_error', 'sent_at',
])]
class ProductCampaignDelivery extends Model
{
    protected function casts(): array
    {
        return [
            'destination' => 'encrypted',
            'sent_at' => 'datetime',
        ];
    }

    public function campaign(): BelongsTo
    {
        return $this->belongsTo(ProductCampaign::class, 'product_campaign_id');
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
