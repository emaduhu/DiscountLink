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
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Illuminate\Validation\Rule;

class AuthController extends Controller
{
    public function register(Request $request, ApiTokenService $tokens, OtpProviderService $otp): JsonResponse
    {
        $request->merge([
            'phone' => $this->normalizePhone((string) $request->input('phone', '')),
        ]);

        $data = $request->validate([
            'role' => ['required', Rule::in(['seller', 'deliverer', 'buyer'])],
            'full_name' => ['required', 'string', 'max:160'],
            'email' => ['required', 'email', 'max:190', Rule::unique('users', 'email')],
            'phone' => ['required', 'string', 'regex:/^\d{12}$/', Rule::unique('users', 'phone')],
            'nida_number' => ['required', 'string', 'min:8', 'max:40', Rule::unique('users', 'nida_number')],
            'password' => ['required', 'string', 'min:6', 'max:120'],
            'address' => ['required', 'string', 'max:255'],
            'latitude' => ['nullable', 'numeric'],
            'longitude' => ['nullable', 'numeric'],
            'fcm_token' => ['nullable', 'string', 'max:255'],
        ], $this->phoneValidationMessages());

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

        abort_if(! $user || ! $user->password || ! Hash::check($data['password'], $user->password), 422, 'Invalid login credentials.');
        abort_unless($user->is_active, 403, 'Your account is blocked.');

        if (! empty($data['fcm_token'])) {
            $user->update(['fcm_token' => $data['fcm_token']]);
        }

        return response()->json([
            'token' => $tokens->issue($user),
            'user' => $user->fresh(),
            'email_verified' => (bool) $user->email_verified_at,
            'phone_verified' => (bool) $user->phone_verified_at,
        ]);
    }

    public function requestPasswordReset(Request $request): JsonResponse
    {
        $request->merge([
            'email' => $this->normalizeEmail((string) $request->input('email', '')),
        ]);

        $data = $request->validate([
            'email' => ['required', 'email', 'max:190'],
        ]);

        $user = $this->findUserByEmail($data['email']);
        if (! $user) {
            return response()->json([
                'message' => 'If this email is registered, a password reset code has been sent.',
            ]);
        }

        $code = (string) random_int(100000, 999999);
        DB::table('password_reset_tokens')->updateOrInsert(
            ['email' => $user->email],
            [
                'token' => Hash::make($code),
                'created_at' => now(),
            ],
        );

        $emailSent = $this->sendRawEmail(
            $user,
            'DiscountLink password reset code',
            "Your DiscountLink password reset code is {$code}. It expires in 15 minutes.",
            'DiscountLink password reset code could not be sent.',
        );

        return response()->json([
            'message' => $emailSent
                ? 'If this email is registered, a password reset code has been sent.'
                : 'Password reset code was created, but the email could not be sent. Contact support or try again shortly.',
            'reset_email_sent' => $emailSent,
            'reset_code' => $this->exposedVerificationCode($code),
        ]);
    }

    public function resetPassword(Request $request): JsonResponse
    {
        $request->merge([
            'email' => $this->normalizeEmail((string) $request->input('email', '')),
            'code' => $this->normalizeVerificationCode((string) $request->input('code', '')),
        ]);

        $data = $request->validate([
            'email' => ['required', 'email', 'max:190'],
            'code' => ['required', 'string', 'size:6'],
            'password' => ['required', 'string', 'min:6', 'max:120', 'confirmed'],
        ]);

        $user = $this->findUserByEmail($data['email']);
        $reset = $user
            ? DB::table('password_reset_tokens')->where('email', $user->email)->first()
            : null;

        abort_if(
            ! $user ||
            ! $reset ||
            ! $reset->created_at ||
            Carbon::parse($reset->created_at)->addMinutes(15)->isPast() ||
            ! Hash::check($data['code'], $reset->token),
            422,
            'Invalid or expired password reset code.',
        );

        $user->update(['password' => $data['password']]);
        DB::table('password_reset_tokens')->where('email', $user->email)->delete();

        return response()->json(['message' => 'Password reset successful. You can now sign in.']);
    }

    public function google(Request $request, GoogleAuthService $google, FirebasePhoneAuthService $firebase, ApiTokenService $tokens, OtpProviderService $otp): JsonResponse
    {
        if ($request->has('phone')) {
            $request->merge([
                'phone' => $this->normalizePhone((string) $request->input('phone', '')),
            ]);
        }

        $data = $request->validate([
            'google_id_token' => ['required_without_all:firebase_id_token,google_access_token', 'string'],
            'google_access_token' => ['required_without_all:firebase_id_token,google_id_token', 'string'],
            'firebase_id_token' => ['required_without_all:google_id_token,google_access_token', 'string'],
            'role' => ['required', Rule::in(['seller', 'deliverer', 'buyer'])],
            'full_name' => ['nullable', 'string', 'max:160'],
            'phone' => ['nullable', 'string', 'regex:/^\d{12}$/'],
            'nida_number' => ['nullable', 'string', 'min:8', 'max:40'],
            'address' => ['nullable', 'string', 'max:255'],
            'latitude' => ['nullable', 'numeric'],
            'longitude' => ['nullable', 'numeric'],
            'fcm_token' => ['nullable', 'string', 'max:255'],
        ], $this->phoneValidationMessages());

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
            ! $user && (empty($data['full_name']) || empty($data['phone']) || empty($data['nida_number']) || empty($data['address'])),
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
        if (! empty($data['full_name'])) {
            $attributes['name'] = $data['full_name'];
        }
        if (! empty($data['phone'])) {
            if (! $user || ! $user->phone || $user->phone === $data['phone']) {
                $this->abortIfPhoneTaken($data['phone'], $user);
                $attributes['phone'] = $data['phone'];
            } else {
                $this->abortIfPhoneTaken($data['phone'], $user);
                $attributes['pending_phone'] = $data['phone'];
            }
        }
        if (! empty($data['nida_number'])) {
            $existingNida = User::where('nida_number', $data['nida_number'])
                ->when($user, fn ($query) => $query->where('id', '!=', $user->id))
                ->exists();
            abort_if($existingNida, 422, 'The NIDA number has already been registered.');
            $attributes['nida_number'] = $data['nida_number'];
        }
        if (! empty($data['address'])) {
            $attributes['address'] = $data['address'];
        }

        $user = User::updateOrCreate(['email' => $email], $attributes);
        $phoneOtp = match (true) {
            $isNewUser => $this->sendPhoneOtp($user, $otp),
            ! empty($attributes['pending_phone']) => $this->sendPhoneOtpTo($user, $attributes['pending_phone'], $otp),
            default => ['sent' => false, 'code' => null],
        };

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
        abort_if(! $otp || $otp->expires_at->isPast() || ! Hash::check($data['code'], $otp->code_hash), 422, 'Invalid or expired email code.');

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
        $request->merge([
            'phone' => $this->normalizePhone((string) $request->input('phone', '')),
        ]);

        $data = $request->validate([
            'phone' => ['required', 'string', 'regex:/^\d{12}$/'],
        ], $this->phoneValidationMessages());
        $this->abortUnlessVerifiablePhone($request->user(), $data['phone']);
        if (! $otp->shouldCreateBackendOtp()) {
            return response()->json([
                'message' => 'Use Firebase phone authentication.',
                'provider' => 'firebase',
            ]);
        }

        $code = (string) random_int(100000, 999999);
        $exposedCode = $this->exposedVerificationCode($code);
        $sent = true;
        $reference = null;

        try {
            $reference = $otp->send($data['phone'], $code);
        } catch (\Throwable $error) {
            $sent = false;
            Log::warning('DiscountLink phone OTP request could not be sent.', [
                'user_id' => $request->user()->id,
                'phone' => $data['phone'],
                'provider' => $otp->activeProvider(),
                'error' => $error->getMessage(),
            ]);
        }

        PhoneOtp::create([
            'user_id' => $request->user()->id,
            'phone' => $data['phone'],
            'code_hash' => $otp->hashCode($code),
            'provider_reference' => $reference,
            'expires_at' => now()->addMinutes(10),
        ]);

        return response()->json([
            'message' => $sent ? 'OTP sent.' : 'OTP was created, but SMS delivery failed. Try again shortly.',
            'provider' => $otp->activeProvider(),
            'phone_otp_sent' => $sent,
            'phone_code' => $exposedCode,
        ]);
    }

    public function verifyOtp(Request $request, OtpProviderService $otp, FirebasePhoneAuthService $firebase): JsonResponse
    {
        $request->merge([
            'phone' => $this->normalizePhone((string) $request->input('phone', '')),
            'code' => $this->normalizeVerificationCode((string) $request->input('code', '')),
        ]);

        $rules = ['phone' => ['required', 'string', 'regex:/^\d{12}$/']];
        if ($otp->activeProvider() === 'firebase') {
            $rules['firebase_id_token'] = ['required', 'string'];
        } else {
            $rules['code'] = ['required', 'string', 'size:6'];
        }

        $data = $request->validate($rules, $this->phoneValidationMessages());

        if ($otp->activeProvider() === 'firebase') {
            $firebase->verifyPhoneToken($data['firebase_id_token'], $data['phone']);
            $this->markPhoneVerified($request->user(), $data['phone']);

            return response()->json(['message' => 'Phone verified.', 'user' => $request->user()->fresh()]);
        }

        $otp = PhoneOtp::where('user_id', $request->user()->id)->where('phone', $data['phone'])->latest()->first();
        abort_if(! $otp || $otp->expires_at->isPast() || ! Hash::check($data['code'], $otp->code_hash), 422, 'Invalid or expired OTP.');

        $otp->update(['verified_at' => now()]);
        $this->markPhoneVerified($request->user(), $data['phone']);

        return response()->json(['message' => 'Phone verified.', 'user' => $request->user()->fresh()]);
    }

    public function me(Request $request): JsonResponse
    {
        return response()->json(['user' => $request->user()]);
    }

    public function updateProfile(Request $request, OtpProviderService $otp): JsonResponse
    {
        if ($request->has('phone')) {
            $request->merge(['phone' => $this->normalizePhone((string) $request->input('phone', ''))]);
        }

        if ($request->has('name')) {
            $request->merge(['name' => trim((string) $request->input('name', ''))]);
        }

        $data = $request->validate([
            'name' => ['sometimes', 'required', 'string', 'max:160'],
            'address' => ['nullable', 'string', 'max:255'],
            'phone' => ['nullable', 'string', 'regex:/^\d{12}$/'],
            'latitude' => ['nullable', 'numeric'],
            'longitude' => ['nullable', 'numeric'],
        ], $this->phoneValidationMessages());

        $user = $request->user();
        $phoneOtp = ['sent' => false, 'code' => null];
        $phoneChanged = false;

        if (array_key_exists('phone', $data)) {
            $phone = $data['phone'];
            unset($data['phone']);

            if ($phone && $phone !== $user->phone) {
                $this->abortIfPhoneTaken($phone, $user);
                $user->update(['pending_phone' => $phone]);
                $phoneOtp = $this->sendPhoneOtpTo($user, $phone, $otp);
                $phoneChanged = true;
            } elseif ($phone === $user->phone && $user->pending_phone) {
                $user->update(['pending_phone' => null]);
            }
        }

        if ($data !== []) {
            $user->update($data);
        }

        return response()->json([
            'message' => $phoneChanged
                ? 'Phone change started. Verify the OTP sent to the new number.'
                : 'Profile updated.',
            'user' => $user->fresh(),
            'phone_change_started' => $phoneChanged,
            'phone_otp_sent' => $phoneOtp['sent'],
            'phone_code' => $phoneOtp['code'],
            'otp_provider' => $otp->activeProvider(),
        ]);
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

        $sent = $this->sendRawEmail(
            $user,
            'DiscountLink email verification code',
            "Your DiscountLink email verification code is {$code}. It expires in 15 minutes.",
            'DiscountLink email OTP could not be sent.',
        );

        return ['sent' => $sent, 'code' => $exposedCode];
    }

    /**
     * @return array{sent: bool, code: string|null}
     */
    private function sendPhoneOtp(User $user, OtpProviderService $otp): array
    {
        if ($user->phone_verified_at || $otp->activeProvider() === 'firebase') {
            return ['sent' => false, 'code' => null];
        }

        return $this->sendPhoneOtpTo($user, $user->phone, $otp);
    }

    /**
     * @return array{sent: bool, code: string|null}
     */
    private function sendPhoneOtpTo(User $user, string $phone, OtpProviderService $otp): array
    {
        if ($otp->activeProvider() === 'firebase') {
            return ['sent' => false, 'code' => null];
        }

        $code = (string) random_int(100000, 999999);
        $exposedCode = $this->exposedVerificationCode($code);

        try {
            $reference = $otp->send($phone, $code);
            PhoneOtp::create([
                'user_id' => $user->id,
                'phone' => $phone,
                'code_hash' => $otp->hashCode($code),
                'provider_reference' => $reference,
                'expires_at' => now()->addMinutes(10),
            ]);

            return ['sent' => true, 'code' => $exposedCode];
        } catch (\Throwable $error) {
            Log::warning('DiscountLink phone OTP could not be sent.', [
                'user_id' => $user->id,
                'phone' => $phone,
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

    private function findUserByEmail(string $email): ?User
    {
        return User::whereRaw('LOWER(email) = ?', [$this->normalizeEmail($email)])->first();
    }

    private function normalizeEmail(string $email): string
    {
        return strtolower(trim($email));
    }

    private function normalizeVerificationCode(string $code): string
    {
        return preg_replace('/\D+/', '', $code) ?? '';
    }

    private function normalizePhone(string $phone): string
    {
        return preg_replace('/[\s-]+/', '', trim($phone)) ?? '';
    }

    /**
     * @return array<string, string>
     */
    private function phoneValidationMessages(): array
    {
        return [
            'phone.regex' => 'Phone number must contain exactly 12 digits, for example 255700000001.',
        ];
    }

    private function abortUnlessVerifiablePhone(User $user, string $phone): void
    {
        $phone = $this->normalizePhone($phone);
        $current = $this->normalizePhone((string) $user->phone);
        $pending = $this->normalizePhone((string) $user->pending_phone);

        abort_unless($phone === $current || ($pending !== '' && $phone === $pending), 422, 'Start the phone number change before requesting an OTP for this number.');
    }

    private function abortIfPhoneTaken(string $phone, ?User $user = null): void
    {
        $taken = User::where(function ($query) use ($phone) {
            $query->where('phone', $phone)->orWhere('pending_phone', $phone);
        })
            ->when($user?->id, fn ($query, $id) => $query->where('id', '!=', $id))
            ->exists();

        abort_if($taken, 422, 'The phone number has already been registered.');
    }

    private function markPhoneVerified(User $user, string $phone): void
    {
        $phone = $this->normalizePhone($phone);
        $this->abortUnlessVerifiablePhone($user, $phone);

        if ($phone === $this->normalizePhone((string) $user->pending_phone)) {
            $this->abortIfPhoneTaken($phone, $user);
            $user->update([
                'phone' => $phone,
                'pending_phone' => null,
                'phone_verified_at' => now(),
            ]);

            return;
        }

        $user->update([
            'phone_verified_at' => now(),
            'pending_phone' => null,
        ]);
    }

    private function sendRawEmail(User $user, string $subject, string $body, string $failureMessage): bool
    {
        try {
            Mail::mailer($this->mailMailer())->raw($body, function ($message) use ($user, $subject) {
                $message->to($user->email, $user->name)->subject($subject);
            });

            return true;
        } catch (\Throwable $error) {
            Log::warning($failureMessage, [
                'user_id' => $user->id,
                'email' => $user->email,
                'mailer' => $this->mailMailer(),
                'error' => $error->getMessage(),
            ]);

            return false;
        }
    }

    private function mailMailer(): string
    {
        $defaultMailer = (string) config('mail.default', 'log');
        $smtpHost = (string) config('mail.mailers.smtp.host', '');
        $smtpUsername = (string) config('mail.mailers.smtp.username', '');

        if (in_array($defaultMailer, ['sendmail', 'log', 'array'], true) && $smtpHost !== '' && $smtpUsername !== '') {
            return 'smtp';
        }

        return $defaultMailer;
    }
}
