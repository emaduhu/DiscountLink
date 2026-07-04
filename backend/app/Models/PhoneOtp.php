<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

#[Fillable(['user_id', 'phone', 'code_hash', 'provider_reference', 'expires_at', 'verified_at'])]
class PhoneOtp extends Model
{
    protected function casts(): array
    {
        return ['expires_at' => 'datetime', 'verified_at' => 'datetime'];
    }
}
