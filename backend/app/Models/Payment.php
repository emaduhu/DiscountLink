<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;

#[Fillable(['order_id', 'shop_id', 'user_id', 'type', 'provider', 'provider_reference', 'status', 'amount', 'phone', 'payload'])]
class Payment extends Model
{
    protected function casts(): array
    {
        return ['payload' => 'array'];
    }

    public function canReceiveUssdPrompt(): bool
    {
        return in_array($this->type, ['collection', 'shop_registration_fee', 'product_campaign'], true)
            && ! in_array($this->status, ['paid', 'success', 'completed'], true)
            && filled($this->phone);
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }

    public function shop(): BelongsTo
    {
        return $this->belongsTo(Shop::class);
    }

    public function productCampaign(): HasOne
    {
        return $this->hasOne(ProductCampaign::class);
    }
}
