<?php

namespace App\Jobs;

use App\Models\ProductCampaign;
use App\Services\ProductCampaignService;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

class DispatchProductCampaign implements ShouldQueue
{
    use Queueable;

    public function __construct(public int $campaignId)
    {
        $this->onQueue('default');
    }

    public function handle(ProductCampaignService $campaigns): void
    {
        $campaign = ProductCampaign::find($this->campaignId);
        if (! $campaign || ! $campaigns->markSending($campaign)) {
            return;
        }

        $campaign->deliveries()
            ->where('status', 'pending')
            ->select('id')
            ->orderBy('id')
            ->chunkById(500, function ($deliveries) {
                foreach ($deliveries as $delivery) {
                    SendProductCampaignMessage::dispatch($delivery->id);
                }
            });
    }
}
