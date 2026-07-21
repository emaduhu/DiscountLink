<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Support\Facades\DB;

class FcmTokenService
{
    /**
     * Assign a device token to one user, revoking any previous owner.
     */
    public function claim(User $user, ?string $token): void
    {
        $token = $token === null ? null : trim($token);
        $token = $token === '' ? null : $token;

        DB::transaction(function () use ($user, $token): void {
            if ($token !== null) {
                User::withTrashed()
                    ->where('fcm_token', $token)
                    ->where('id', '!=', $user->id)
                    ->update(['fcm_token' => null]);
            }

            $user->forceFill(['fcm_token' => $token])->save();
        });
    }
}
