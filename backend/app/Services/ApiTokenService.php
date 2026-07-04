<?php

namespace App\Services;

use App\Models\ApiToken;
use App\Models\User;
use Illuminate\Support\Str;

class ApiTokenService
{
    public function issue(User $user, string $name = 'mobile'): string
    {
        $plain = Str::random(80);
        ApiToken::create([
            'user_id' => $user->id,
            'name' => $name,
            'token_hash' => hash('sha256', $plain),
            'expires_at' => now()->addDays((int) config('services.discountlink.token_days', 90)),
        ]);

        return $plain;
    }
}
