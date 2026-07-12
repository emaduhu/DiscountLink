<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Fillable(['seller_id', 'name', 'category', 'categories', 'address', 'latitude', 'longitude', 'is_active', 'registration_fee_amount', 'registration_fee_status', 'registration_fee_payment_id', 'registration_paid_at'])]
class Shop extends Model
{
    protected function casts(): array
    {
        return [
            'categories' => 'array',
            'is_active' => 'boolean',
            'registration_fee_amount' => 'decimal:2',
            'registration_paid_at' => 'datetime',
        ];
    }

    public function seller(): BelongsTo
    {
        return $this->belongsTo(User::class, 'seller_id');
    }

    public function products(): HasMany
    {
        return $this->hasMany(Product::class);
    }

    public function registrationFeePayment(): BelongsTo
    {
        return $this->belongsTo(Payment::class, 'registration_fee_payment_id');
    }
}
