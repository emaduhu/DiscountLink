<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Fillable(['shop_id', 'seller_id', 'name', 'description', 'price', 'discount_price', 'discount_percent', 'delivery_price', 'auto_total', 'images', 'stock', 'is_active'])]
class Product extends Model
{
    protected $with = ['media'];

    protected function casts(): array
    {
        return ['images' => 'array', 'is_active' => 'boolean'];
    }

    public function shop(): BelongsTo
    {
        return $this->belongsTo(Shop::class);
    }

    public function seller(): BelongsTo
    {
        return $this->belongsTo(User::class, 'seller_id');
    }

    public function ratings(): HasMany
    {
        return $this->hasMany(ProductRating::class);
    }

    public function media(): HasMany
    {
        return $this->hasMany(ProductMedia::class)->orderBy('sort_order');
    }
}
