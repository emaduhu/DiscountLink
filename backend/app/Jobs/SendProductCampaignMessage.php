<?php

namespace App\Jobs;

use App\Models\ProductCampaignDelivery;
use App\Services\FcmService;
use App\Services\OtpProviderService;
use App\Services\ProductCampaignService;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use RuntimeException;
use Throwable;

class SendProductCampaignMessage implements ShouldQueue
{
    use Queueable;

    public function __construct(public int $deliveryId)
    {
        $this->onQueue('default');
    }

    public function tries(): int
    {
        return 3;
    }

    /** @return array<int, int> */
    public function backoff(): array
    {
        return [60, 300];
    }

    public function handle(
        ProductCampaignService $campaigns,
        OtpProviderService $sms,
        FcmService $fcm,
    ): void {
        $delivery = ProductCampaignDelivery::with(['campaign.product', 'user'])->find($this->deliveryId);
        if (! $delivery || in_array($delivery->status, ['sent', 'failed'], true)) {
            return;
        }

        $claimed = ProductCampaignDelivery::whereKey($delivery->id)
            ->where('status', 'pending')
            ->update([
                'status' => 'processing',
                'attempt_count' => $delivery->attempt_count + 1,
                'updated_at' => now(),
            ]);
        if ($claimed !== 1) {
            return;
        }

        $delivery->refresh();
        $user = $delivery->user;
        if (! $user || ! $user->is_active) {
            $campaigns->completeDelivery($delivery, false, error: 'Campaign recipient is no longer active.');

            return;
        }

        try {
            if ($delivery->campaign->channel === ProductCampaignService::CHANNEL_SMS) {
                $providerReference = $sms->sendMessage($delivery->destination, $delivery->campaign->message);
            } else {
                // Use the snapshotted token even if the user has since refreshed their device token.
                $user->setAttribute('fcm_token', $delivery->destination);
                $isNewProductAnnouncement = str_starts_with((string) $delivery->campaign->reference, 'DLNEW-');
                $sent = $fcm->sendToUser($user, $delivery->campaign->title, $delivery->campaign->message, [
                    'type' => $isNewProductAnnouncement ? 'product_added' : 'product_campaign',
                    'route' => 'product',
                    'campaign_id' => (string) $delivery->campaign->id,
                    'product_id' => (string) $delivery->campaign->product_id,
                    'seller_id' => (string) $delivery->campaign->seller_id,
                ]);
                if (! $sent) {
                    throw new RuntimeException('FCM did not accept the campaign notification.');
                }
                $providerReference = null;
            }

            $campaigns->completeDelivery($delivery, true, $providerReference);
        } catch (Throwable $error) {
            if ($delivery->attempt_count < $this->tries()) {
                ProductCampaignDelivery::whereKey($delivery->id)
                    ->where('status', 'processing')
                    ->update([
                        'status' => 'pending',
                        'last_error' => substr($error->getMessage(), 0, 2000),
                        'updated_at' => now(),
                    ]);

                throw $error;
            }

            report($error);
            $campaigns->completeDelivery($delivery, false, error: $error->getMessage());
        }
    }

    public function failed(?Throwable $error): void
    {
        $delivery = ProductCampaignDelivery::find($this->deliveryId);
        if ($delivery && ! in_array($delivery->status, ['sent', 'failed'], true)) {
            app(ProductCampaignService::class)->completeDelivery(
                $delivery,
                false,
                error: $error?->getMessage() ?: 'Campaign delivery job failed.',
            );
        }
    }
}
