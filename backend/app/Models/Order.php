<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

#[Fillable(['reference', 'buyer_id', 'seller_id', 'shop_id', 'status', 'delivery_address', 'subtotal', 'delivery_total', 'grand_total', 'delivery_code_hash', 'paid_at', 'delivered_at'])]
class Order extends Model
{
    protected function casts(): array
    {
        return ['paid_at' => 'datetime', 'delivered_at' => 'datetime'];
    }

    public function buyer(): BelongsTo { return $this->belongsTo(User::class, 'buyer_id'); }
    public function seller(): BelongsTo { return $this->belongsTo(User::class, 'seller_id'); }
    public function shop(): BelongsTo { return $this->belongsTo(Shop::class); }
    public function items(): HasMany { return $this->hasMany(OrderItem::class); }
    public function deliveryAssignment(): HasOne { return $this->hasOne(DeliveryAssignment::class); }
}
