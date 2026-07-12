<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

#[Fillable(['reference', 'buyer_id', 'seller_id', 'shop_id', 'status', 'delivery_address', 'subtotal', 'delivery_total', 'service_fee_rate', 'service_fee_total', 'grand_total', 'delivery_code_hash', 'delivery_code_demo', 'paid_at', 'delivered_at'])]
class Order extends Model
{
    protected function casts(): array
    {
        return [
            'paid_at' => 'datetime',
            'delivered_at' => 'datetime',
            'service_fee_rate' => 'decimal:2',
            'service_fee_total' => 'decimal:2',
        ];
    }

    public function buyer(): BelongsTo { return $this->belongsTo(User::class, 'buyer_id'); }
    public function seller(): BelongsTo { return $this->belongsTo(User::class, 'seller_id'); }
    public function shop(): BelongsTo { return $this->belongsTo(Shop::class); }
    public function items(): HasMany { return $this->hasMany(OrderItem::class); }
    public function deliveryAssignment(): HasOne { return $this->hasOne(DeliveryAssignment::class); }
}
