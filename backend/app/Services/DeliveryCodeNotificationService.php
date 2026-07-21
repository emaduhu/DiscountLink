<?php

namespace App\Services;

use App\Models\Order;
use App\Models\User;
use Illuminate\Support\Facades\Log;
use Throwable;

class DeliveryCodeNotificationService
{
    public function __construct(
        private readonly OtpProviderService $sms,
        private readonly FcmService $fcm,
    ) {}

    /**
     * @return array{sms: bool, fcm: bool}
     */
    public function send(User $buyer, Order $order, string $deliveryCode): array
    {
        $message = "Your Vigour Deals delivery code for order {$order->reference} is {$deliveryCode}. Share it only after receiving your order.";
        $smsSent = false;

        if ($buyer->phone) {
            try {
                $smsSent = $this->sms->sendMessage($buyer->phone, $message) !== null;
            } catch (Throwable $error) {
                Log::warning('Buyer delivery code SMS could not be sent.', [
                    'buyer_id' => $buyer->id,
                    'order_id' => $order->id,
                    'error' => $error->getMessage(),
                ]);
            }
        }

        $fcmSent = false;
        try {
            $fcmSent = $this->fcm->sendToUser(
                $buyer,
                'Your delivery code',
                $message,
                [
                    'type' => 'delivery_code',
                    'order_id' => (string) $order->id,
                    'reference' => $order->reference,
                    'delivery_code' => $deliveryCode,
                ],
            );
        } catch (Throwable $error) {
            Log::warning('Buyer delivery code FCM notification could not be sent.', [
                'buyer_id' => $buyer->id,
                'order_id' => $order->id,
                'error' => $error->getMessage(),
            ]);
        }

        return ['sms' => $smsSent, 'fcm' => $fcmSent];
    }
}
