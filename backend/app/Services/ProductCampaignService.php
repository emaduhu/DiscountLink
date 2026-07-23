<?php

namespace App\Services;

use App\Jobs\DispatchProductCampaign;
use App\Models\AppSetting;
use App\Models\Payment;
use App\Models\Product;
use App\Models\ProductCampaign;
use App\Models\ProductCampaignDelivery;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class ProductCampaignService
{
    public const CHANNEL_SMS = 'sms';

    public const CHANNEL_FCM = 'fcm';

    /** @return array<string, array<string, int|float|string>> */
    public function pricing(): array
    {
        return collect([self::CHANNEL_SMS, self::CHANNEL_FCM])
            ->mapWithKeys(function (string $channel) {
                $unitPrice = $this->unitPrice($channel);
                $recipients = $this->eligibleRecipients($channel)->count();

                return [$channel => [
                    'unit_price' => $unitPrice,
                    'eligible_recipient_count' => $recipients,
                    'estimated_total' => round($unitPrice * $recipients, 2),
                    'currency' => 'TZS',
                ]];
            })
            ->all();
    }

    /**
     * Create an immutable audience and price snapshot before requesting payment.
     *
     * @return array{campaign: ProductCampaign, payment: ?Payment}
     */
    public function create(User $seller, Product $product, string $channel, ?string $paymentPhone): array
    {
        $this->assertChannel($channel);
        $unitPrice = $this->unitPrice($channel);
        [$title, $message] = $this->platformMessage($product);

        return DB::transaction(function () use ($seller, $product, $channel, $paymentPhone, $unitPrice, $title, $message) {
            $campaign = ProductCampaign::create([
                'reference' => 'DLC-'.now()->format('YmdHis').'-'.Str::upper(Str::random(8)),
                'seller_id' => $seller->id,
                'product_id' => $product->id,
                'channel' => $channel,
                'status' => 'pending_payment',
                'title' => $title,
                'message' => $message,
                'unit_price' => $unitPrice,
            ]);

            $recipientCount = $this->snapshotRecipients($campaign);
            if ($recipientCount === 0) {
                throw ValidationException::withMessages([
                    'channel' => "There are no eligible {$channel} recipients right now.",
                ]);
            }

            $totalCost = round($unitPrice * $recipientCount, 2);
            if ($totalCost > 999999999999.99) {
                throw ValidationException::withMessages([
                    'channel' => 'The campaign total exceeds the supported payment limit. Lower the configured channel price.',
                ]);
            }
            $campaign->update([
                'recipient_count' => $recipientCount,
                'total_cost' => $totalCost,
            ]);

            if ($totalCost <= 0) {
                $campaign->update([
                    'status' => 'queued',
                    'paid_at' => now(),
                ]);
                DispatchProductCampaign::dispatch($campaign->id)->afterCommit();

                return ['campaign' => $campaign->fresh(), 'payment' => null];
            }

            $payment = Payment::create([
                'user_id' => $seller->id,
                'type' => 'product_campaign',
                'provider' => 'clickpesa',
                'status' => 'pending',
                'amount' => $totalCost,
                'phone' => $paymentPhone ?: $seller->phone,
                'payload' => [
                    'campaign_id' => $campaign->id,
                    'campaign_reference' => $campaign->reference,
                    'channel' => $channel,
                    'recipient_count' => $recipientCount,
                    'unit_price' => $unitPrice,
                ],
            ]);
            $campaign->update(['payment_id' => $payment->id]);

            return ['campaign' => $campaign->fresh(), 'payment' => $payment];
        });
    }

    public function announceNewProduct(Product $product): ?ProductCampaign
    {
        $product->loadMissing('shop');
        if (! $product->is_active || ! $product->shop?->is_active) {
            return null;
        }

        [$title, $message] = $this->newProductMessage($product);

        return DB::transaction(function () use ($product, $title, $message): ?ProductCampaign {
            $campaign = ProductCampaign::create([
                'reference' => 'DLNEW-'.now()->format('YmdHis').'-'.Str::upper(Str::random(8)),
                'seller_id' => $product->seller_id,
                'product_id' => $product->id,
                'channel' => self::CHANNEL_FCM,
                'status' => 'queued',
                'title' => $title,
                'message' => $message,
                'unit_price' => 0,
                'total_cost' => 0,
                'paid_at' => now(),
            ]);

            $recipientCount = $this->snapshotRecipients($campaign);
            if ($recipientCount === 0) {
                $campaign->delete();

                return null;
            }

            $campaign->update([
                'recipient_count' => $recipientCount,
            ]);

            DispatchProductCampaign::dispatch($campaign->id)->afterCommit();

            return $campaign->fresh();
        });
    }

    public function syncPaymentStatus(Payment $payment): void
    {
        if ($payment->type !== 'product_campaign') {
            return;
        }

        $paidStatuses = ['paid', 'success', 'completed'];
        $failedStatuses = ['failed', 'cancelled', 'canceled', 'expired'];

        DB::transaction(function () use ($payment, $paidStatuses, $failedStatuses) {
            $campaign = ProductCampaign::where('payment_id', $payment->id)->lockForUpdate()->first();
            if (! $campaign || in_array($campaign->status, ['completed', 'completed_with_errors'], true)) {
                return;
            }

            if (in_array($payment->status, $paidStatuses, true)) {
                $shouldDispatch = $campaign->paid_at === null;
                $campaign->update([
                    'status' => in_array($campaign->status, ['pending_payment', 'payment_failed'], true)
                        ? 'queued'
                        : $campaign->status,
                    'paid_at' => $campaign->paid_at ?: now(),
                ]);

                if ($shouldDispatch) {
                    DispatchProductCampaign::dispatch($campaign->id)->afterCommit();
                }

                return;
            }

            if (in_array($payment->status, $failedStatuses, true) && $campaign->paid_at === null) {
                $campaign->update(['status' => 'payment_failed']);
            }
        });
    }

    public function markSending(ProductCampaign $campaign): bool
    {
        return DB::transaction(function () use ($campaign) {
            $locked = ProductCampaign::lockForUpdate()->find($campaign->id);
            if (! $locked || ! in_array($locked->status, ['queued', 'sending'], true)) {
                return false;
            }

            if ($locked->paid_at === null && (float) $locked->total_cost > 0) {
                return false;
            }

            if ($locked->status === 'queued') {
                $locked->update([
                    'status' => 'sending',
                    'started_at' => $locked->started_at ?: now(),
                ]);
            }

            return true;
        });
    }

    public function completeDelivery(
        ProductCampaignDelivery $delivery,
        bool $sent,
        ?string $providerReference = null,
        ?string $error = null,
    ): void {
        DB::transaction(function () use ($delivery, $sent, $providerReference, $error) {
            $lockedDelivery = ProductCampaignDelivery::lockForUpdate()->find($delivery->id);
            if (! $lockedDelivery || in_array($lockedDelivery->status, ['sent', 'failed'], true)) {
                return;
            }

            $lockedDelivery->update([
                'status' => $sent ? 'sent' : 'failed',
                'provider_reference' => $providerReference,
                'last_error' => $sent ? null : Str::limit($error ?: 'Provider rejected the message.', 2000, ''),
                'sent_at' => $sent ? now() : null,
            ]);

            $campaign = ProductCampaign::lockForUpdate()->find($lockedDelivery->product_campaign_id);
            if (! $campaign || in_array($campaign->status, ['completed', 'completed_with_errors'], true)) {
                return;
            }

            if ($sent) {
                $campaign->sent_count++;
            } else {
                $campaign->failed_count++;
            }

            if (($campaign->sent_count + $campaign->failed_count) >= $campaign->recipient_count) {
                $campaign->status = $campaign->failed_count > 0 ? 'completed_with_errors' : 'completed';
                $campaign->completed_at = now();
            }
            $campaign->save();
        });
    }

    public function unitPrice(string $channel): float
    {
        $this->assertChannel($channel);
        $key = $channel === self::CHANNEL_SMS ? 'campaign_sms_unit_price' : 'campaign_fcm_unit_price';

        return max(0, round((float) AppSetting::get($key, '0.00'), 4));
    }

    private function eligibleRecipients(string $channel): Builder
    {
        $this->assertChannel($channel);

        return User::query()
            ->where('is_active', true)
            ->whereIn('role', ['buyer', 'seller', 'deliverer'])
            ->when(
                $channel === self::CHANNEL_SMS,
                fn (Builder $query) => $query
                    ->whereNotNull('phone')
                    ->where('phone', '<>', '')
                    ->whereNotNull('phone_verified_at'),
                fn (Builder $query) => $query
                    ->whereNotNull('fcm_token')
                    ->where('fcm_token', '<>', ''),
            );
    }

    private function snapshotRecipients(ProductCampaign $campaign): int
    {
        $count = 0;

        $this->eligibleRecipients($campaign->channel)
            ->select(['id', 'phone', 'fcm_token'])
            ->orderBy('id')
            ->chunkById(500, function ($users) use ($campaign, &$count) {
                $timestamp = now();
                $rows = $users->map(function (User $user) use ($campaign, $timestamp) {
                    $destination = $campaign->channel === self::CHANNEL_SMS ? $user->phone : $user->fcm_token;

                    return [
                        'product_campaign_id' => $campaign->id,
                        'user_id' => $user->id,
                        'destination' => Crypt::encryptString((string) $destination),
                        'status' => 'pending',
                        'attempt_count' => 0,
                        'created_at' => $timestamp,
                        'updated_at' => $timestamp,
                    ];
                })->all();

                ProductCampaignDelivery::insert($rows);
                $count += count($rows);
            });

        return $count;
    }

    /** @return array{string, string} */
    private function platformMessage(Product $product): array
    {
        $productName = Str::limit(trim($product->name), 60, '');
        $shopName = Str::limit(trim((string) $product->shop?->name), 45, '');
        $price = (float) ($product->discount_price ?? $product->price);
        $title = Str::limit("Featured deal: {$productName}", 120, '');
        $message = "Vigour Deals: {$productName} from {$shopName} is TZS ".number_format($price, 2).". Open the app to view product #{$product->id}.";

        return [$title, Str::limit($message, 320, '')];
    }

    /** @return array{string, string} */
    private function newProductMessage(Product $product): array
    {
        $productName = Str::limit(trim($product->name), 60, '');
        $shopName = Str::limit(trim((string) $product->shop?->name), 45, '');
        $price = (float) ($product->discount_price ?? $product->price);
        $title = Str::limit("New product: {$productName}", 120, '');
        $message = "Vigour Deals: {$shopName} just added {$productName} for TZS ".number_format($price, 2).". Open the app to view product #{$product->id}.";

        return [$title, Str::limit($message, 320, '')];
    }

    private function assertChannel(string $channel): void
    {
        if (! in_array($channel, [self::CHANNEL_SMS, self::CHANNEL_FCM], true)) {
            throw ValidationException::withMessages(['channel' => 'Campaign channel must be sms or fcm.']);
        }
    }
}
