<?php

namespace App\Services;

use App\Models\Payment;
use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use RuntimeException;

class ClickPesaService
{
    public function requestUssdPush(Payment $payment, string $currency = 'TZS'): array
    {
        $prefix = $payment->type === 'shop_registration_fee' ? 'DLSHOP' : 'DLPAY';

        if (! $this->isConfigured()) {
            $this->abortUnlessLocalFallbackAllowed('ClickPesa payment push is not configured. Set CLICKPESA_CLIENT_ID and CLICKPESA_API_KEY.');
        }

        if (! $this->isConfigured()) {
            $orderReference = $this->orderReference($payment, $prefix);
            $payment->update([
                'provider_reference' => 'local-'.$payment->id,
                'status' => 'processing',
                'payload' => ['orderReference' => $orderReference, 'status' => 'processing'],
            ]);

            return ['reference' => $payment->provider_reference, 'orderReference' => $orderReference, 'status' => $payment->status];
        }

        $orderReference = $this->orderReference($payment, $prefix);
        $existingPayload = is_array($payment->payload) ? $payment->payload : [];
        $orderReferences = $this->orderReferences($existingPayload, $orderReference);
        $payload = [
            'amount' => $this->amount($payment),
            'currency' => $currency,
            'orderReference' => $orderReference,
            'phoneNumber' => $this->phone($payment->phone),
        ];
        $payment->update([
            'provider' => 'clickpesa',
            'status' => 'processing',
            'payload' => array_merge($existingPayload, [
                'orderReference' => $orderReference,
                'orderReferences' => $orderReferences,
                'request' => $payload,
            ]),
        ]);

        try {
            $preview = $this->postClickPesa('/third-parties/payments/preview-ussd-push-request', $payload);
            $initiate = $this->postClickPesa('/third-parties/payments/initiate-ussd-push-request', $payload);
        } catch (ValidationException $error) {
            $existingPayload = is_array($payment->payload) ? $payment->payload : [];
            $payment->update([
                'provider' => 'clickpesa',
                'provider_reference' => $orderReference,
                'status' => 'failed',
                'payload' => array_merge($existingPayload, [
                    'orderReference' => $orderReference,
                    'orderReferences' => $orderReferences,
                    'request' => $payload,
                    'error' => $error->errors(),
                ]),
            ]);

            throw $error;
        }

        $transactionId = $this->firstData($initiate, [
            'id',
            'transaction.id',
            'transactionId',
            'payment.id',
            'data.id',
        ]);
        $status = $this->normalizeStatus($this->firstData($initiate, [
            'status',
            'transaction.status',
            'payment.status',
            'data.status',
        ], 'processing'));

        $storedPayload = array_merge(is_array($payment->payload) ? $payment->payload : [], [
            'orderReference' => $orderReference,
            'orderReferences' => $orderReferences,
            'preview' => $preview,
            'initiate' => $initiate,
        ]);

        $payment->update([
            'provider' => 'clickpesa',
            'provider_reference' => $transactionId ?: $orderReference,
            'status' => $status,
            'payload' => $storedPayload,
        ]);

        Log::info('ClickPesa USSD push requested.', [
            'payment_id' => $payment->id,
            'order_reference' => $orderReference,
            'provider_reference' => $payment->provider_reference,
            'status' => $status,
            'phone' => $payload['phoneNumber'],
            'amount' => $payload['amount'],
            'channel' => $this->firstData($initiate, ['channel', 'data.channel']),
        ]);

        return [
            'reference' => $payment->provider_reference,
            'orderReference' => $orderReference,
            'status' => $status,
            'preview' => $preview,
            'initiate' => $initiate,
        ];
    }

    public function disburse(Payment $payment, string $currency = 'TZS'): array
    {
        if (! $this->isConfigured()) {
            $this->abortUnlessLocalFallbackAllowed('ClickPesa disbursement is not configured. Set CLICKPESA_CLIENT_ID and CLICKPESA_API_KEY.');
        }

        if (! $this->isConfigured()) {
            $orderReference = $this->orderReference($payment, 'DLDISB');
            $payment->update([
                'provider_reference' => 'local-disburse-'.$payment->id,
                'status' => 'paid',
                'payload' => ['orderReference' => $orderReference, 'status' => 'paid'],
            ]);

            return ['reference' => $payment->provider_reference, 'orderReference' => $orderReference, 'status' => 'paid'];
        }

        $orderReference = $this->orderReference($payment, 'DLDISB');
        $payload = [
            'amount' => $this->amount($payment),
            'currency' => $currency,
            'orderReference' => $orderReference,
            'phoneNumber' => $this->phone($payment->phone),
            'reason' => 'DiscountLink '.$payment->type,
        ];
        $existingPayload = is_array($payment->payload) ? $payment->payload : [];
        $payment->update([
            'provider' => 'clickpesa',
            'status' => 'processing',
            'payload' => array_merge($existingPayload, [
                'orderReference' => $orderReference,
                'request' => $payload,
            ]),
        ]);

        $response = $this->postClickPesa('/third-parties/payouts/mobile-money', $payload);

        $transactionId = $this->firstData($response, [
            'id',
            'transaction.id',
            'transactionId',
            'payout.id',
            'data.id',
        ]);
        $status = $this->normalizeStatus($this->firstData($response, [
            'status',
            'transaction.status',
            'payout.status',
            'data.status',
        ], 'processing'));

        $payment->update([
            'provider' => 'clickpesa',
            'provider_reference' => $transactionId ?: $orderReference,
            'status' => $status,
            'payload' => array_merge(is_array($payment->payload) ? $payment->payload : [], [
                'orderReference' => $orderReference,
                'payout' => $response,
            ]),
        ]);

        return [
            'reference' => $payment->provider_reference,
            'orderReference' => $orderReference,
            'status' => $status,
            'payout' => $response,
        ];
    }

    public function applyCallback(array $payload): void
    {
        $reference = $this->firstData($payload, [
            'id',
            'transaction.id',
            'transactionId',
            'payment.id',
            'payout.id',
            'data.id',
        ]);
        $orderReference = $this->firstData($payload, [
            'orderReference',
            'order_reference',
            'transaction.orderReference',
            'data.orderReference',
        ]);

        if (! $reference && ! $orderReference) {
            Log::warning('ClickPesa callback did not include a transaction id or order reference.', $payload);

            return;
        }

        $payment = Payment::query()
            ->when($reference, fn ($query) => $query->orWhere('provider_reference', $reference))
            ->when($orderReference, fn ($query) => $query->orWhere('payload->orderReference', $orderReference))
            ->first();

        if (! $payment) {
            Log::warning('Unknown ClickPesa callback', $payload);

            return;
        }

        $status = $this->normalizeStatus($this->firstData($payload, [
            'status',
            'transaction.status',
            'payment.status',
            'payout.status',
            'data.status',
        ], $payment->status));

        $existingPayload = is_array($payment->payload) ? $payment->payload : [];
        $payment->update([
            'status' => $status,
            'payload' => array_merge($existingPayload, ['callback' => $payload]),
        ]);

        if ($payment->type === 'collection' && in_array($status, ['paid', 'success', 'completed'], true)) {
            $payment->order?->update(['status' => 'paid', 'paid_at' => now()]);
        }

        if ($payment->type === 'shop_registration_fee') {
            if (in_array($status, ['paid', 'success', 'completed'], true)) {
                $payment->shop?->update([
                    'is_active' => true,
                    'registration_fee_status' => 'paid',
                    'registration_fee_payment_id' => $payment->id,
                    'registration_paid_at' => now(),
                ]);
            } elseif (in_array($status, ['failed', 'cancelled', 'canceled', 'expired'], true)) {
                $payment->shop?->update([
                    'is_active' => false,
                    'registration_fee_status' => 'failed',
                    'registration_fee_payment_id' => $payment->id,
                ]);
            }
        }
    }

    public function token(bool $forceRefresh = false): string
    {
        if ($forceRefresh) {
            Cache::forget($this->tokenCacheKey());
        }

        return Cache::remember($this->tokenCacheKey(), now()->addMinutes(50), function () {
            $payload = $this->requestTokenPayload();
            $token = $this->firstData($payload, ['token', 'accessToken', 'access_token', 'data.token']);

            if (! is_string($token) || trim($token) === '') {
                throw new RuntimeException('ClickPesa token response did not include a token.');
            }

            return trim($token);
        });
    }

    private function requestTokenPayload(): array
    {
        $handle = curl_init($this->url('/third-parties/generate-token'));
        curl_setopt_array($handle, [
            CURLOPT_POST => true,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => $this->timeout(),
            CURLOPT_HTTPHEADER => [
                'Accept: application/json',
                'client-id: '.(string) config('services.clickpesa.client_id'),
                'api-key: '.(string) config('services.clickpesa.api_key'),
            ],
        ]);

        $body = curl_exec($handle);
        $status = curl_getinfo($handle, CURLINFO_RESPONSE_CODE);
        $error = curl_error($handle);
        curl_close($handle);

        if ($body === false || $status < 200 || $status >= 300) {
            throw new RuntimeException('ClickPesa token request failed with status '.$status.($error ? ': '.$error : '.'));
        }

        $payload = json_decode((string) $body, true);
        if (! is_array($payload)) {
            throw new RuntimeException('ClickPesa token response was not valid JSON.');
        }

        return $payload;
    }

    private function client()
    {
        $token = $this->token();

        $request = Http::timeout($this->timeout())->acceptJson();
        if (Str::startsWith($token, 'Bearer ')) {
            return $request->withHeaders(['Authorization' => $token]);
        }

        return $request->withToken($token);
    }

    private function postClickPesa(string $path, array $payload): array
    {
        $response = $this->client()->post($this->url($path), $payload);
        if (! $response->successful()) {
            throw ValidationException::withMessages([
                'payment' => $this->clickPesaErrorMessage($response),
            ]);
        }

        $json = $response->json();

        return is_array($json) ? $json : [];
    }

    private function clickPesaErrorMessage(Response $response): string
    {
        $message = data_get($response->json(), 'message')
            ?: data_get($response->json(), 'error')
            ?: 'ClickPesa could not send the USSD payment push.';

        if (str_contains(strtolower((string) $message), 'm-pesa payment method is not active')) {
            return 'ClickPesa rejected the payment push: M-Pesa payment method is not active on this ClickPesa account. Ask ClickPesa to activate M-Pesa collections, then try checkout again.';
        }

        return 'ClickPesa rejected the payment push: '.$message;
    }

    private function tokenCacheKey(): string
    {
        return 'clickpesa.jwt.'.sha1((string) config('services.clickpesa.client_id'));
    }

    private function isConfigured(): bool
    {
        return filled(config('services.clickpesa.client_id')) && filled(config('services.clickpesa.api_key'));
    }

    private function url(string $path): string
    {
        return rtrim((string) config('services.clickpesa.base_url'), '/').'/'.ltrim($path, '/');
    }

    private function timeout(): int
    {
        return (int) config('services.clickpesa.timeout', 30);
    }

    private function amount(Payment $payment): string
    {
        return number_format((float) $payment->amount, 2, '.', '');
    }

    private function phone(string $phone): string
    {
        $phone = preg_replace('/[\s-]+/', '', trim($phone)) ?? '';
        $phone = ltrim($phone, '+');

        if (! preg_match('/^\d{12}$/', $phone)) {
            throw ValidationException::withMessages([
                'phone' => 'Payment phone number must contain exactly 12 digits, for example 255700000001.',
            ]);
        }

        return $phone;
    }

    private function abortUnlessLocalFallbackAllowed(string $message): void
    {
        if (app()->environment('local', 'testing')) {
            return;
        }

        throw ValidationException::withMessages(['payment' => $message]);
    }

    private function orderReference(Payment $payment, string $prefix): string
    {
        $base = $prefix.str_pad((string) $payment->id, 10, '0', STR_PAD_LEFT);
        $existing = data_get($payment->payload, 'orderReference');

        if (is_string($existing) && $existing !== '' && ! $this->needsNewOrderReference($payment)) {
            return $existing;
        }

        if (! $this->needsNewOrderReference($payment)) {
            return $base;
        }

        $references = data_get($payment->payload, 'orderReferences');
        $references = is_array($references) ? array_filter($references, 'is_string') : [];
        $nextAttempt = collect($references)
            ->filter(fn (string $reference) => preg_match('/R\d+$/', $reference) === 1)
            ->count();

        do {
            $nextAttempt++;
            $reference = $base.'R'.str_pad((string) $nextAttempt, 2, '0', STR_PAD_LEFT);
        } while (in_array($reference, $references, true));

        return $reference;
    }

    private function needsNewOrderReference(Payment $payment): bool
    {
        $payload = is_array($payment->payload) ? $payment->payload : [];

        return filled($payment->provider_reference)
            || in_array($payment->status, ['failed', 'processing'], true)
            || filled(data_get($payload, 'request'))
            || filled(data_get($payload, 'preview'))
            || filled(data_get($payload, 'initiate'))
            || filled(data_get($payload, 'error'));
    }

    /**
     * @param  array<string, mixed>  $payload
     * @return array<int, string>
     */
    private function orderReferences(array $payload, string $orderReference): array
    {
        $references = data_get($payload, 'orderReferences', []);
        $references = is_array($references) ? array_filter($references, 'is_string') : [];
        $references[] = $orderReference;

        return array_values(array_unique($references));
    }

    /**
     * @param  array<int, string>  $paths
     */
    private function firstData(array $payload, array $paths, mixed $default = null): mixed
    {
        foreach ($paths as $path) {
            $value = data_get($payload, $path);
            if ($value !== null && $value !== '') {
                return $value;
            }
        }

        return $default;
    }

    private function normalizeStatus(mixed $status): string
    {
        $status = strtolower((string) $status);

        return match ($status) {
            'successful', 'succeeded', 'complete' => 'paid',
            'pending', 'queued', 'initiated' => 'processing',
            'failed', 'failure', 'cancelled', 'canceled', 'expired' => 'failed',
            default => $status !== '' ? $status : 'processing',
        };
    }
}
