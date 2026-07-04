<?php

namespace App\Services;

use App\Models\Payment;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class ClickPesaService
{
    public function requestUssdPush(Payment $payment, string $currency = 'TZS'): array
    {
        if (!config('services.clickpesa.api_key') || app()->environment('local')) {
            $payment->update(['provider_reference' => 'local-'.$payment->id, 'status' => 'processing']);
            return ['reference' => $payment->provider_reference, 'status' => $payment->status];
        }

        $response = Http::withToken(config('services.clickpesa.api_key'))
            ->acceptJson()
            ->post(rtrim(config('services.clickpesa.base_url'), '/').'/payments/ussd-push', [
                'amount' => $payment->amount,
                'currency' => $currency,
                'phone_number' => $payment->phone,
                'external_reference' => 'DL-PAY-'.$payment->id,
                'callback_url' => route('api.clickpesa.callback'),
            ]);

        $response->throw();
        $payload = $response->json();
        $payment->update([
            'provider_reference' => data_get($payload, 'reference', data_get($payload, 'id')),
            'status' => data_get($payload, 'status', 'processing'),
            'payload' => $payload,
        ]);
        return $payload;
    }

    public function disburse(Payment $payment, string $currency = 'TZS'): array
    {
        if (!config('services.clickpesa.api_key') || app()->environment('local')) {
            $payment->update(['provider_reference' => 'local-disburse-'.$payment->id, 'status' => 'paid']);
            return ['reference' => $payment->provider_reference, 'status' => 'paid'];
        }

        $response = Http::withToken(config('services.clickpesa.api_key'))
            ->acceptJson()
            ->post(rtrim(config('services.clickpesa.base_url'), '/').'/disbursements', [
                'amount' => $payment->amount,
                'currency' => $currency,
                'phone_number' => $payment->phone,
                'external_reference' => 'DL-DISB-'.$payment->id,
            ]);

        $response->throw();
        $payload = $response->json();
        $payment->update([
            'provider_reference' => data_get($payload, 'reference', data_get($payload, 'id')),
            'status' => data_get($payload, 'status', 'processing'),
            'payload' => $payload,
        ]);
        return $payload;
    }

    public function applyCallback(array $payload): void
    {
        $reference = data_get($payload, 'reference') ?? data_get($payload, 'id');
        $payment = Payment::where('provider_reference', $reference)->first();
        if (!$payment) {
            Log::warning('Unknown ClickPesa callback', $payload);
            return;
        }
        $status = data_get($payload, 'status', $payment->status);
        $payment->update(['status' => $status, 'payload' => $payload]);
        if ($payment->type === 'collection' && in_array($status, ['paid', 'success', 'completed'], true)) {
            $payment->order?->update(['status' => 'paid', 'paid_at' => now()]);
        }
    }
}
