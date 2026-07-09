<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\EmailOtp;
use App\Models\PhoneOtp;
use App\Models\User;
use App\Services\ApiTokenService;
use App\Services\FirebasePhoneAuthService;
use App\Services\GoogleAuthService;
use App\Services\OtpProviderService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Illuminate\Validation\Rule;

class AuthController extends Controller
{
    public function register(Request $request, ApiTokenService $tokens, OtpProviderService $otp): JsonResponse
    {
        $data = $request->validate([
            'role' => ['required', Rule::in(['seller', 'deliverer', 'buyer'])],
            'full_name' => ['required', 'string', 'max:160'],
            'email' => ['required', 'email', 'max:190', Rule::unique('users', 'email')],
            'phone' => ['required', 'string', 'max:30', Rule::unique('users', 'phone')],
            'nida_number' => ['required', 'string', 'min:8', 'max:40', Rule::unique('users', 'nida_number')],
            'password' => ['required', 'string', 'min:6', 'max:120'],
            'address' => ['required', 'string', 'max:255'],
            'latitude' => ['nullable', 'numeric'],
            'longitude' => ['nullable', 'numeric'],
            'fcm_token' => ['nullable', 'string', 'max:255'],
        ]);

        $user = User::create([
            'role' => $data['role'],
            'name' => $data['full_name'],
            'email' => $data['email'],
            'email_verified_at' => null,
            'password' => $data['password'],
            'phone' => $data['phone'],
            'nida_number' => $data['nida_number'],
            'address' => $data['address'],
            'latitude' => $data['latitude'] ?? null,
            'longitude' => $data['longitude'] ?? null,
            'fcm_token' => $data['fcm_token'] ?? null,
            'is_active' => true,
        ]);

        $emailOtp = $this->sendEmailOtp($user);
        $phoneOtp = $this->sendPhoneOtp($user, $otp);

        return response()->json([
            'token' => $tokens->issue($user),
            'user' => $user->fresh(),
            'email_verified' => false,
            'phone_verified' => false,
            'email_otp_sent' => $emailOtp['sent'],
            'phone_otp_sent' => $phoneOtp['sent'],
            'verification_codes' => [
                'email' => $emailOtp['code'],
                'phone' => $phoneOtp['code'],
            ],
            'otp_provider' => $otp->activeProvider(),
        ], 201);
    }

    public function login(Request $request, ApiTokenService $tokens): JsonResponse
    {
        $data = $request->validate([
            'identifier' => ['required', 'string', 'max:190'],
            'password' => ['required', 'string'],
            'fcm_token' => ['nullable', 'string', 'max:255'],
        ]);

        $identifier = $data['identifier'];
        $user = User::where('email', $identifier)
            ->orWhere('phone', $identifier)
            ->first();

        abort_if(!$user || !$user->password || !Hash::check($data['password'], $user->password), 422, 'Invalid login credentials.');
        abort_unless($user->is_active, 403, 'Your account is blocked.');

        if (!empty($data['fcm_token'])) {
            $user->update(['fcm_token' => $data['fcm_token']]);
        }

        return response()->json([
            'token' => $tokens->issue($user),
            'user' => $user->fresh(),
            'email_verified' => (bool) $user->email_verified_at,
            'phone_verified' => (bool) $user->phone_verified_at,
        ]);
    }

    public function google(Request $request, GoogleAuthService $google, FirebasePhoneAuthService $firebase, ApiTokenService $tokens, OtpProviderService $otp): JsonResponse
    {
        $data = $request->validate([
            'google_id_token' => ['required_without_all:firebase_id_token,google_access_token', 'string'],
            'google_access_token' => ['required_without_all:firebase_id_token,google_id_token', 'string'],
            'firebase_id_token' => ['required_without_all:google_id_token,google_access_token', 'string'],
            'role' => ['required', Rule::in(['seller', 'deliverer', 'buyer'])],
            'full_name' => ['nullable', 'string', 'max:160'],
            'phone' => ['nullable', 'string', 'max:30'],
            'nida_number' => ['nullable', 'string', 'min:8', 'max:40'],
            'address' => ['nullable', 'string', 'max:255'],
            'latitude' => ['nullable', 'numeric'],
            'longitude' => ['nullable', 'numeric'],
            'fcm_token' => ['nullable', 'string', 'max:255'],
        ]);

        $profile = match (true) {
            ! empty($data['firebase_id_token']) => $firebase->verifyAuthToken($data['firebase_id_token']),
            ! empty($data['google_access_token']) => $google->verifyAccessToken($data['google_access_token']),
            default => $google->verify($data['google_id_token']),
        };
        $email = $profile['email'] ?? null;
        abort_unless($email, 422, 'The selected account must expose an email address.');

        $user = User::where('email', $email)->first();
        $isNewUser = ! $user;
        abort_if(
            !$user && (empty($data['full_name']) || empty($data['phone']) || empty($data['nida_number']) || empty($data['address'])),
            422,
            'Complete registration with your name, phone, NIDA number, and address before using social sign-in.'
        );

        $attributes = [
            'google_id' => $profile['sub'] ?? $profile['user_id'] ?? null,
            'email_verified_at' => now(),
            'latitude' => $data['latitude'] ?? null,
            'longitude' => $data['longitude'] ?? null,
            'fcm_token' => $data['fcm_token'] ?? null,
        ];
        if (! $user) {
            $attributes['role'] = $data['role'];
        }
        if (!empty($data['full_name'])) {
            $attributes['name'] = $data['full_name'];
        }
        if (!empty($data['phone'])) {
            $attributes['phone'] = $data['phone'];
        }
        if (!empty($data['nida_number'])) {
            $existingNida = User::where('nida_number', $data['nida_number'])->where('email', '!=', $email)->exists();
            abort_if($existingNida, 422, 'The NIDA number has already been registered.');
            $attributes['nida_number'] = $data['nida_number'];
        }
        if (!empty($data['address'])) {
            $attributes['address'] = $data['address'];
        }

        $user = User::updateOrCreate(['email' => $email], $attributes);
        $phoneOtp = $isNewUser ? $this->sendPhoneOtp($user, $otp) : ['sent' => false, 'code' => null];

        return response()->json([
            'token' => $tokens->issue($user),
            'user' => $user,
            'email_verified' => (bool) $user->email_verified_at,
            'phone_verified' => (bool) $user->phone_verified_at,
            'phone_otp_sent' => $phoneOtp['sent'],
            'verification_codes' => [
                'email' => null,
                'phone' => $phoneOtp['code'],
            ],
            'otp_provider' => $otp->activeProvider(),
        ]);
    }

    public function requestEmailOtp(Request $request): JsonResponse
    {
        $otp = $this->sendEmailOtp($request->user());

        return response()->json([
            'message' => $otp['sent'] ? 'Email verification code sent.' : 'Email verification code could not be sent.',
            'email_otp_sent' => $otp['sent'],
            'email_code' => $otp['code'],
        ]);
    }

    public function verifyEmailOtp(Request $request): JsonResponse
    {
        $data = $request->validate(['code' => ['required', 'string', 'size:6']]);
        $user = $request->user();
        $otp = EmailOtp::where('user_id', $user->id)->where('email', $user->email)->latest()->first();
        abort_if(!$otp || $otp->expires_at->isPast() || !Hash::check($data['code'], $otp->code_hash), 422, 'Invalid or expired email code.');

        $otp->update(['verified_at' => now()]);
        $user->update(['email_verified_at' => now()]);

        return response()->json(['message' => 'Email verified.', 'user' => $user->fresh()]);
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

        return response()->json([
            'message' => 'OTP sent.',
            'provider' => $otp->activeProvider(),
            'phone_code' => $this->exposedVerificationCode($code),
        ]);
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

    public function updateProfile(Request $request): JsonResponse
    {
        $data = $request->validate([
            'address' => ['nullable', 'string', 'max:255'],
            'latitude' => ['nullable', 'numeric'],
            'longitude' => ['nullable', 'numeric'],
        ]);

        $request->user()->update($data);

        return response()->json(['user' => $request->user()->fresh()]);
    }

    public function updateFcm(Request $request): JsonResponse
    {
        $data = $request->validate(['fcm_token' => ['required', 'string', 'max:255']]);
        $request->user()->update($data);
        return response()->json(['message' => 'FCM token updated.']);
    }

    /**
     * @return array{sent: bool, code: string|null}
     */
    private function sendEmailOtp(User $user): array
    {
        if ($user->email_verified_at) {
            return ['sent' => true, 'code' => null];
        }

        $code = (string) random_int(100000, 999999);
        $exposedCode = $this->exposedVerificationCode($code);
        EmailOtp::create([
            'user_id' => $user->id,
            'email' => $user->email,
            'code_hash' => Hash::make($code),
            'expires_at' => now()->addMinutes(15),
        ]);

        try {
            Mail::raw("Your DiscountLink email verification code is {$code}. It expires in 15 minutes.", function ($message) use ($user) {
                $message->to($user->email, $user->name)->subject('DiscountLink email verification code');
            });

            return ['sent' => true, 'code' => $exposedCode];
        } catch (\Throwable $error) {
            Log::warning('DiscountLink email OTP could not be sent.', [
                'user_id' => $user->id,
                'email' => $user->email,
                'error' => $error->getMessage(),
            ]);

            return ['sent' => false, 'code' => $exposedCode];
        }
    }

    /**
     * @return array{sent: bool, code: string|null}
     */
    private function sendPhoneOtp(User $user, OtpProviderService $otp): array
    {
        if ($user->phone_verified_at || $otp->activeProvider() === 'firebase') {
            return ['sent' => false, 'code' => null];
        }

        $code = (string) random_int(100000, 999999);
        $exposedCode = $this->exposedVerificationCode($code);

        try {
            $reference = $otp->send($user->phone, $code);
            PhoneOtp::create([
                'user_id' => $user->id,
                'phone' => $user->phone,
                'code_hash' => $otp->hashCode($code),
                'provider_reference' => $reference,
                'expires_at' => now()->addMinutes(10),
            ]);

            return ['sent' => true, 'code' => $exposedCode];
        } catch (\Throwable $error) {
            Log::warning('DiscountLink phone OTP could not be sent.', [
                'user_id' => $user->id,
                'phone' => $user->phone,
                'provider' => $otp->activeProvider(),
                'error' => $error->getMessage(),
            ]);

            return ['sent' => false, 'code' => $exposedCode];
        }
    }

    private function exposedVerificationCode(string $code): ?string
    {
        return (bool) config('services.discountlink.show_verification_codes') ? $code : null;
    }
}
