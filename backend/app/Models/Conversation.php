<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Fillable(['order_id', 'product_id', 'user_one_id', 'user_two_id', 'blocked_by_id', 'blocked_at', 'block_reason'])]
class Conversation extends Model
{
    protected function casts(): array
    {
        return ['blocked_at' => 'datetime'];
    }

    public function userOne(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_one_id');
    }

    public function userTwo(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_two_id');
    }

    public function messages(): HasMany
    {
        return $this->hasMany(Message::class);
    }

    public function reports(): HasMany
    {
        return $this->hasMany(ConversationReport::class);
    }

    public function blocker(): BelongsTo
    {
        return $this->belongsTo(User::class, 'blocked_by_id');
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }
}
