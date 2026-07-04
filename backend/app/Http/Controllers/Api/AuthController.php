<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\PhoneOtp;
use App\Models\User;
use App\Services\ApiTokenService;
use App\Services\BeemOtpService;
use App\Services\GoogleAuthService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;

class AuthController extends Controller
{
    public function google(Request $request, GoogleAuthService $google, ApiTokenService $tokens): JsonResponse
    {
        $data = $request->validate([
            'google_id_token' => ['required', 'string'],
            'role' => ['required', Rule::in(['seller', 'deliverer', 'buyer'])],
            'full_name' => ['required', 'string', 'max:160'],
            'phone' => ['required', 'string', 'max:30'],
            'address' => ['required', 'string', 'max:255'],
            'latitude' => ['nullable', 'numeric'],
            'longitude' => ['nullable', 'numeric'],
            'fcm_token' => ['nullable', 'string', 'max:255'],
        ]);

        $profile = $google->verify($data['google_id_token']);
        $email = $profile['email'] ?? null;
        abort_unless($email, 422, 'Google account must expose an email address.');

        $user = User::updateOrCreate(
            ['email' => $email],
            [
                'google_id' => $profile['sub'] ?? null,
                'email_verified_at' => now(),
                'role' => $data['role'],
                'name' => $data['full_name'],
                'phone' => $data['phone'],
                'address' => $data['address'],
                'latitude' => $data['latitude'] ?? null,
                'longitude' => $data['longitude'] ?? null,
                'fcm_token' => $data['fcm_token'] ?? null,
            ]
        );

        return response()->json(['token' => $tokens->issue($user), 'user' => $user, 'phone_verified' => (bool) $user->phone_verified_at]);
    }

    public function requestOtp(Request $request, BeemOtpService $beem): JsonResponse
    {
        $data = $request->validate(['phone' => ['required', 'string', 'max:30']]);
        $code = (string) random_int(100000, 999999);
        $reference = $beem->send($data['phone'], $code);

        PhoneOtp::create([
            'user_id' => $request->user()->id,
            'phone' => $data['phone'],
            'code_hash' => Hash::make($code),
            'provider_reference' => $reference,
            'expires_at' => now()->addMinutes(10),
        ]);

        return response()->json(['message' => 'OTP sent.']);
    }

    public function verifyOtp(Request $request): JsonResponse
    {
        $data = $request->validate(['phone' => ['required', 'string'], 'code' => ['required', 'string', 'size:6']]);
        $otp = PhoneOtp::where('user_id', $request->user()->id)->where('phone', $data['phone'])->latest()->first();
        abort_if(!$otp || $otp->expires_at->isPast() || !Hash::check($data['code'], $otp->code_hash), 422, 'Invalid or expired OTP.');

        $otp->update(['verified_at' => now()]);
        $request->user()->update(['phone' => $data['phone'], 'phone_verified_at' => now()]);

        return response()->json(['message' => 'Phone verified.', 'user' => $request->user()->fresh()]);
    }

    public function me(Request $request): JsonResponse
    {
        return response()->json(['user' => $request->user()]);
    }

    public function updateFcm(Request $request): JsonResponse
    {
        $data = $request->validate(['fcm_token' => ['required', 'string', 'max:255']]);
        $request->user()->update($data);
        return response()->json(['message' => 'FCM token updated.']);
    }
}
