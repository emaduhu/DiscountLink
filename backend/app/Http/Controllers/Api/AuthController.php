<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\PhoneOtp;
use App\Models\User;
use App\Services\ApiTokenService;
use App\Services\FirebasePhoneAuthService;
use App\Services\GoogleAuthService;
use App\Services\OtpProviderService;
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

    public function otpProvider(OtpProviderService $otp): JsonResponse
    {
        return response()->json(['provider' => $otp->activeProvider()]);
    }

    public function requestOtp(Request $request, OtpProviderService $otp): JsonResponse
    {
        $data = $request->validate(['phone' => ['required', 'string', 'max:30']]);
        if (!$otp->shouldCreateBackendOtp()) {
            return response()->json([
                'message' => 'Use Firebase phone authentication.',
                'provider' => 'firebase',
            ]);
        }

        $code = (string) random_int(100000, 999999);
        $reference = $otp->send($data['phone'], $code);

        PhoneOtp::create([
            'user_id' => $request->user()->id,
            'phone' => $data['phone'],
            'code_hash' => $otp->hashCode($code),
            'provider_reference' => $reference,
            'expires_at' => now()->addMinutes(10),
        ]);

        return response()->json(['message' => 'OTP sent.', 'provider' => $otp->activeProvider()]);
    }

    public function verifyOtp(Request $request, OtpProviderService $otp, FirebasePhoneAuthService $firebase): JsonResponse
    {
        $rules = ['phone' => ['required', 'string']];
        if ($otp->activeProvider() === 'firebase') {
            $rules['firebase_id_token'] = ['required', 'string'];
        } else {
            $rules['code'] = ['required', 'string', 'size:6'];
        }

        $data = $request->validate($rules);

        if ($otp->activeProvider() === 'firebase') {
            $firebase->verifyPhoneToken($data['firebase_id_token'], $data['phone']);
            $request->user()->update(['phone' => $data['phone'], 'phone_verified_at' => now()]);

            return response()->json(['message' => 'Phone verified.', 'user' => $request->user()->fresh()]);
        }

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
