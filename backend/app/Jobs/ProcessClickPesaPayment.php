<?php

namespace App\Jobs;

use App\Models\Payment;
use App\Services\ClickPesaService;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Support\Facades\Log;
use Throwable;

class ProcessClickPesaPayment implements ShouldQueue
{
    use Queueable;

    public function __construct(
        public int $paymentId,
        public string $operation,
    ) {
        $this->onQueue((string) config('services.clickpesa.queue', 'payments'));
    }

    public static function queueUssdPush(Payment $payment): void
    {
        self::markQueued($payment, 'ussd_push');

        self::dispatch($payment->id, 'ussd_push')->afterCommit();
    }

    public static function queueDisbursement(Payment $payment): void
    {
        self::markQueued($payment, 'disbursement');

        self::dispatch($payment->id, 'disbursement')->afterCommit();
    }

    public function tries(): int
    {
        return (int) config('services.clickpesa.queue_tries', 5);
    }

    /**
     * @return array<int, int>
     */
    public function backoff(): array
    {
        return [60, 300, 900, 1800, 3600];
    }

    public function handle(ClickPesaService $clickPesa): void
    {
        $payment = Payment::find($this->paymentId);
        if (! $payment || $this->alreadySent($payment)) {
            return;
        }

        try {
            $this->markAttempting($payment);

            if ($this->operation === 'disbursement') {
                $clickPesa->disburse($payment);
            } else {
                $clickPesa->requestUssdPush($payment);
            }
        } catch (Throwable $error) {
            $this->markRetrying($payment->fresh() ?? $payment, $error);

            throw $error;
        }
    }

    public function failed(Throwable $error): void
    {
        $payment = Payment::find($this->paymentId);
        if (! $payment || $this->alreadySent($payment)) {
            return;
        }

        $payload = is_array($payment->payload) ? $payment->payload : [];
        $attempts = $payload['queue_attempts'] ?? [];
        $attempts[] = $this->attemptPayload($error);

        $payment->update([
            'status' => 'failed',
            'payload' => array_merge($payload, [
                'queued_operation' => $this->operation,
                'queue_attempts' => $attempts,
                'queue_failed_at' => now()->toIso8601String(),
                'queue_error' => $error->getMessage(),
            ]),
        ]);

        if ($payment->type === 'shop_registration_fee') {
            $payment->shop?->update(['registration_fee_status' => 'failed']);
        }

        Log::error('ClickPesa queued payment failed permanently.', [
            'payment_id' => $payment->id,
            'operation' => $this->operation,
            'error' => $error->getMessage(),
        ]);
    }

    private static function markQueued(Payment $payment, string $operation): void
    {
        $payload = is_array($payment->payload) ? $payment->payload : [];

        $payment->update([
            'provider' => 'clickpesa',
            'status' => 'queued',
            'payload' => array_merge($payload, [
                'queued_operation' => $operation,
                'queued_at' => now()->toIso8601String(),
            ]),
        ]);
    }

    private function markAttempting(Payment $payment): void
    {
        $payload = is_array($payment->payload) ? $payment->payload : [];

        $payment->update([
            'payload' => array_merge($payload, [
                'queued_operation' => $this->operation,
                'last_queue_attempt_at' => now()->toIso8601String(),
            ]),
        ]);
    }

    private function markRetrying(Payment $payment, Throwable $error): void
    {
        if ($this->alreadySent($payment)) {
            return;
        }

        $payload = is_array($payment->payload) ? $payment->payload : [];
        $attempts = $payload['queue_attempts'] ?? [];
        $attempts[] = $this->attemptPayload($error);

        $payment->update([
            'status' => 'retrying',
            'payload' => array_merge($payload, [
                'queued_operation' => $this->operation,
                'queue_attempts' => $attempts,
                'last_queue_error' => $error->getMessage(),
            ]),
        ]);
    }

    private function attemptPayload(Throwable $error): array
    {
        return [
            'attempt' => $this->attempts(),
            'failed_at' => now()->toIso8601String(),
            'error' => $error->getMessage(),
        ];
    }

    private function alreadySent(Payment $payment): bool
    {
        $payload = is_array($payment->payload) ? $payment->payload : [];

        if (in_array($payment->status, ['paid', 'success', 'completed'], true)) {
            return true;
        }

        if ($this->operation === 'disbursement') {
            return isset($payload['payout']);
        }

        return isset($payload['initiate'])
            || str_starts_with((string) $payment->provider_reference, 'local-');
    }
}
