<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AppSetting;
use App\Models\Cart;
use App\Models\DeliveryAssignment;
use App\Models\DiscountLink;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Payment;
use App\Models\Product;
use App\Models\User;
use App\Services\ClickPesaService;
use App\Services\DeliveryCodeNotificationService;
use App\Services\FcmService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Throwable;

class CartController extends Controller
{
    private function userCanBuy(User $user): bool
    {
        return in_array($user->role, ['buyer', 'seller'], true);
    }

    private function deliveryCode(): string
    {
        $digits = range(0, 9);

        for ($i = count($digits) - 1; $i > 0; $i--) {
            $j = random_int(0, $i);
            [$digits[$i], $digits[$j]] = [$digits[$j], $digits[$i]];
        }

        return implode('', array_slice($digits, 0, 4));
    }

    public function index(Request $request): JsonResponse
    {
        $itemsQuery = Cart::with(['product.shop', 'discountLink'])
            ->where('buyer_id', $request->user()->id)
            ->whereHas('product', fn ($productQuery) => $productQuery
                ->where('is_active', true)
                ->where('stock', '>', 0)
                ->whereHas('shop', fn ($shopQuery) => $shopQuery->where('is_active', true)))
            ->when(trim((string) $request->query('q')), fn ($query, string $search) => $query
                ->where(fn ($builder) => $builder
                    ->whereHas('product', fn ($productQuery) => $productQuery
                        ->where('name', 'like', "%{$search}%")
                        ->orWhere('description', 'like', "%{$search}%")
                        ->orWhereHas('shop', fn ($shopQuery) => $shopQuery->where('name', 'like', "%{$search}%")))
                    ->orWhereHas('discountLink', fn ($discountQuery) => $discountQuery->where('token', 'like', "%{$search}%"))));

        $summaryItems = (clone $itemsQuery)->get();
        $items = $this->shouldPaginate($request)
            ? $itemsQuery->latest()->paginate($this->perPage($request))
            : $summaryItems;

        $subtotal = $summaryItems->sum(fn ($item) => $this->cartUnitPrice($item) * $item->quantity);
        $delivery = $summaryItems->sum(fn ($item) => $item->product->delivery_price * $item->quantity);
        $serviceFeeRate = $this->serviceFeeRate();
        $serviceFee = $this->serviceFeeTotal($subtotal, $serviceFeeRate);

        return response()->json([
            'items' => $items,
            'service_fee' => [
                'rate' => $serviceFeeRate,
                'amount' => $serviceFee,
                'currency' => 'TZS',
                'enabled' => $serviceFeeRate > 0,
            ],
            'summary' => [
                'subtotal' => $subtotal,
                'delivery_total' => $delivery,
                'service_fee_total' => $serviceFee,
                'grand_total' => $subtotal + $delivery + $serviceFee,
            ],
        ]);
    }

    public function add(Request $request, Product $product): JsonResponse
    {
        abort_unless($this->userCanBuy($request->user()), 403, 'Only buyers and sellers can add to cart.');
        abort_unless(
            $product->is_active && $product->stock > 0 && $product->shop?->is_active,
            422,
            'This product is no longer available.',
        );
        $data = $request->validate(['quantity' => ['required', 'integer', 'min:1']]);
        abort_unless($data['quantity'] <= $product->stock, 422, 'Requested quantity exceeds available stock.');
        $item = Cart::updateOrCreate(['buyer_id' => $request->user()->id, 'product_id' => $product->id], ['quantity' => $data['quantity']]);

        return response()->json(['item' => $item->load('product')], 201);
    }

    public function showDiscountLink(Request $request, string $token): JsonResponse
    {
        $discountLink = DiscountLink::with('product.shop')
            ->where('token', $token)
            ->firstOrFail();

        abort_unless($discountLink->buyer_id === $request->user()->id || $discountLink->seller_id === $request->user()->id, 403);

        return response()->json([
            'discount_link' => $discountLink,
            'is_valid' => $this->discountLinkIsValid($discountLink),
        ]);
    }

    public function addDiscountLink(Request $request, string $token): JsonResponse
    {
        abort_unless($this->userCanBuy($request->user()), 403, 'Only buyers and sellers can add discount links to cart.');
        $data = $request->validate(['quantity' => ['nullable', 'integer', 'min:1']]);
        $discountLink = DiscountLink::with('product.shop')
            ->where('token', $token)
            ->firstOrFail();

        abort_unless($discountLink->buyer_id === $request->user()->id, 403, 'This discount link belongs to another buyer.');
        abort_unless($this->discountLinkIsValid($discountLink), 422, 'This discount link is expired or already used.');
        abort_unless(
            $discountLink->product->is_active
                && $discountLink->product->stock > 0
                && $discountLink->product->shop?->is_active,
            422,
            'This product is no longer available.',
        );

        $item = Cart::updateOrCreate(
            ['buyer_id' => $request->user()->id, 'product_id' => $discountLink->product_id],
            [
                'discount_link_id' => $discountLink->id,
                'quantity' => $data['quantity'] ?? 1,
                'unit_price_override' => $discountLink->discount_price,
            ],
        );

        return response()->json(['item' => $item->load(['product.shop', 'discountLink'])], 201);
    }

    public function remove(Request $request, Product $product): JsonResponse
    {
        abort_unless($this->userCanBuy($request->user()), 403, 'Only buyers and sellers can remove cart items.');
        Cart::where('buyer_id', $request->user()->id)->where('product_id', $product->id)->delete();

        return response()->json(['message' => 'Item removed from cart.']);
    }

    public function checkout(
        Request $request,
        FcmService $fcm,
        ClickPesaService $clickPesa,
        DeliveryCodeNotificationService $deliveryCodeNotifications,
    ): JsonResponse {
        abort_unless($this->userCanBuy($request->user()), 403);
        abort_unless($request->user()->phone && $request->user()->phone_verified_at, 422, 'Verify your phone before payment.');
        $data = $request->validate([
            'delivery_address' => ['nullable', 'string', 'max:255'],
            'phone' => ['nullable', 'string', 'regex:/^\d{12}$/'],
        ], [
            'phone.regex' => 'Payment phone number must contain exactly 12 digits, for example 255700000001.',
        ]);
        $items = Cart::with(['product.shop', 'discountLink'])->where('buyer_id', $request->user()->id)->get();
        abort_if($items->isEmpty(), 422, 'Cart is empty.');
        abort_if(
            $items->contains(fn (Cart $item) => ! $item->product->is_active
                || $item->product->stock < $item->quantity
                || ! $item->product->shop?->is_active),
            422,
            'One or more cart products are no longer available.',
        );
        $closedItem = $items->first(fn (Cart $item) => ! $item->product->shop->isOpenAt());
        if ($closedItem !== null) {
            $shop = $closedItem->product->shop;
            $nextOpeningAt = $shop->next_status_change_at;

            return response()->json([
                'message' => $shop->name.' is currently closed.'.($nextOpeningAt ? " It opens at {$nextOpeningAt}." : ''),
                'shop' => [
                    'id' => $shop->id,
                    'name' => $shop->name,
                    'is_open' => false,
                    'next_opening_at' => $nextOpeningAt,
                ],
            ], 422);
        }

        $order = DB::transaction(function () use ($request, $items, $data) {
            $first = $items->first()->product;
            $subtotal = $items->sum(fn ($item) => $this->cartUnitPrice($item) * $item->quantity);
            $delivery = $items->sum(fn ($item) => $item->product->delivery_price * $item->quantity);
            $serviceFeeRate = $this->serviceFeeRate();
            $serviceFee = $this->serviceFeeTotal($subtotal, $serviceFeeRate);
            $code = $this->deliveryCode();
            $order = Order::create([
                'reference' => 'DL-'.now()->format('YmdHis').'-'.Str::upper(Str::random(5)),
                'buyer_id' => $request->user()->id,
                'seller_id' => $first->seller_id,
                'shop_id' => $first->shop_id,
                'delivery_address' => $data['delivery_address'] ?: $request->user()->address,
                'subtotal' => $subtotal,
                'delivery_total' => $delivery,
                'service_fee_rate' => $serviceFeeRate,
                'service_fee_total' => $serviceFee,
                'grand_total' => $subtotal + $delivery + $serviceFee,
                'delivery_code_hash' => Hash::make($code),
                'delivery_code_demo' => null,
                'delivery_code_encrypted' => $code,
            ]);
            foreach ($items as $item) {
                $unit = $this->cartUnitPrice($item);
                OrderItem::create([
                    'order_id' => $order->id,
                    'product_id' => $item->product_id,
                    'name' => $item->product->name,
                    'quantity' => $item->quantity,
                    'unit_price' => $unit,
                    'delivery_price' => $item->product->delivery_price,
                    'line_total' => ($unit + $item->product->delivery_price) * $item->quantity,
                ]);
            }
            $assignment = DeliveryAssignment::create(['order_id' => $order->id]);
            $order->setAttribute('plain_delivery_code', $code);
            $order->setRelation('deliveryAssignment', $assignment);

            return $order;
        });

        $payment = Payment::create([
            'order_id' => $order->id,
            'user_id' => $request->user()->id,
            'type' => 'collection',
            'provider' => 'clickpesa',
            'status' => 'pending',
            'amount' => $order->grand_total,
            'phone' => $data['phone'] ?? $request->user()->phone,
        ]);
        try {
            $ussdPush = $clickPesa->requestUssdPush($payment);
        } catch (Throwable $error) {
            throw $this->paymentRequestException($error);
        }

        DiscountLink::whereIn('id', $items->pluck('discount_link_id')->filter()->all())->update(['used_at' => now()]);
        Cart::where('buyer_id', $request->user()->id)->delete();

        $order->loadMissing('shop');
        $assignment = $order->deliveryAssignment;
        $nearestDeliverer = $this->nearestAvailableDeliverer($order);
        if ($nearestDeliverer && $assignment) {
            $assignment->update(['deliverer_id' => $nearestDeliverer->id]);
            $order->setRelation('deliveryAssignment', $assignment->fresh('deliverer'));
        }

        $assignmentId = (string) $order->deliveryAssignment?->id;
        $deliverers = $nearestDeliverer
            ? collect([$nearestDeliverer])
            : User::where('role', 'deliverer')
                ->where('is_active', true)
                ->where('is_available', true)
                ->whereNotNull('fcm_token')
                ->get();

        $deliverers->each(fn ($deliverer) => $fcm->sendToUser($deliverer, 'New delivery request', 'Open DiscountLink to accept order '.$order->reference.'.', [
            'type' => 'delivery_request',
            'order_id' => (string) $order->id,
            'delivery_assignment_id' => $assignmentId,
            'reference' => $order->reference,
        ]));

        $deliveryCode = $order->plain_delivery_code;
        $notificationStatus = $deliveryCodeNotifications->send($request->user(), $order, $deliveryCode);
        $loadedOrder = $order->load('items');
        $loadedOrder->setAttribute('delivery_code', $deliveryCode);

        return response()->json([
            'order' => $loadedOrder,
            'payment' => $payment->fresh(),
            'ussd_push' => $ussdPush,
            'delivery_code' => $deliveryCode,
            'delivery_code_demo' => $deliveryCode,
            'delivery_code_notifications' => $notificationStatus,
            'message' => $this->paymentRequestMessage($payment->fresh(), $ussdPush).' Keep this buyer delivery code. Share it only after receiving the order to release seller and delivery payments.',
        ], 201);
    }

    public function resendPaymentPrompt(Request $request, Payment $payment, ClickPesaService $clickPesa): JsonResponse
    {
        abort_unless($payment->user_id === $request->user()->id, 403);
        abort_unless(in_array($payment->type, ['collection', 'shop_registration_fee'], true), 422, 'This payment cannot receive a phone prompt.');
        abort_if($payment->isPaid(), 422, 'This payment is already complete.');

        if ($payment->type === 'shop_registration_fee') {
            abort_unless($request->user()->role === 'seller', 403);
            abort_unless(
                $payment->shop
                    && ! $payment->shop->trashed()
                    && $payment->shop->seller_id === $request->user()->id,
                404,
            );
        }

        $this->normalizePaymentPhone($request, 'payment_phone');
        $this->normalizePaymentPhone($request, 'phone');
        $data = $request->validate([
            'payment_phone' => ['nullable', 'string', 'regex:/^\d{12}$/'],
            'phone' => ['nullable', 'string', 'regex:/^\d{12}$/'],
        ], [
            'payment_phone.regex' => 'Payment phone number must contain exactly 12 digits, for example 255700000001.',
            'phone.regex' => 'Payment phone number must contain exactly 12 digits, for example 255700000001.',
        ]);

        $correctedPhone = $data['payment_phone'] ?? $data['phone'] ?? null;
        if ($correctedPhone) {
            $payment->update(['phone' => $correctedPhone]);
        }
        abort_unless($payment->phone, 422, 'This payment does not have a phone number.');

        try {
            $ussdPush = $clickPesa->requestUssdPush($payment);
        } catch (Throwable $error) {
            throw $this->paymentRequestException($error);
        }

        if ($payment->type === 'shop_registration_fee') {
            $payment->shop?->update(['registration_fee_status' => 'processing']);
        }

        return response()->json([
            'payment' => $payment->fresh(),
            'ussd_push' => $ussdPush,
            'message' => $this->paymentRequestMessage($payment->fresh(), $ussdPush),
        ]);
    }

    private function paymentRequestMessage(Payment $payment, array $ussdPush): string
    {
        $reference = $ussdPush['reference'] ?? $payment->provider_reference ?? $ussdPush['orderReference'] ?? '-';
        $channel = data_get($ussdPush, 'initiate.channel') ?: data_get($ussdPush, 'channel');

        return trim('Payment request sent to '.$payment->phone.'. Reference: '.$reference.($channel ? '. Channel: '.$channel : '').'. Check your phone and approve the USSD prompt.');
    }

    private function paymentRequestException(Throwable $error): ValidationException
    {
        if ($error instanceof ValidationException) {
            return $error;
        }

        report($error);

        return ValidationException::withMessages([
            'payment' => 'Payment request could not be sent right now. Check the payment provider configuration and try again.',
        ]);
    }

    private function cartUnitPrice(Cart $item): float
    {
        if ($item->unit_price_override !== null && $item->discountLink && $this->discountLinkIsValid($item->discountLink)) {
            return (float) $item->unit_price_override;
        }

        return $this->productEffectivePrice($item->product);
    }

    private function productEffectivePrice(Product $product): float
    {
        $price = (float) $product->price;
        if ($product->discount_price !== null) {
            return (float) $product->discount_price;
        }

        $discountPercent = max(0, min(100, (float) ($product->discount_percent ?? 0)));
        if ($discountPercent <= 0) {
            return $price;
        }

        return round($price * (1 - ($discountPercent / 100)), 2);
    }

    private function normalizePaymentPhone(Request $request, string $key): void
    {
        $phone = $request->input($key);
        if (! is_string($phone)) {
            return;
        }

        $phone = trim($phone);
        if (str_starts_with($phone, '+')) {
            $phone = substr($phone, 1);
        }

        $request->merge([
            $key => preg_replace('/[\s-]+/', '', $phone) ?? '',
        ]);
    }

    private function discountLinkIsValid(DiscountLink $discountLink): bool
    {
        return $discountLink->used_at === null
            && ($discountLink->expires_at === null || $discountLink->expires_at->isFuture())
            && $discountLink->product?->is_active
            && $discountLink->product->stock > 0
            && $discountLink->product->shop?->is_active;
    }

    private function serviceFeeRate(): float
    {
        return max(0, round((float) AppSetting::get('service_fee_percentage', '0'), 2));
    }

    private function serviceFeeTotal(float $subtotal, float $rate): float
    {
        return round($subtotal * ($rate / 100), 2);
    }

    private function nearestAvailableDeliverer(Order $order): ?User
    {
        $shopLatitude = $order->shop?->latitude;
        $shopLongitude = $order->shop?->longitude;
        if ($shopLatitude === null || $shopLongitude === null) {
            return null;
        }

        return User::where('role', 'deliverer')
            ->where('is_active', true)
            ->where('is_available', true)
            ->whereNotNull('fcm_token')
            ->whereNotNull('latitude')
            ->whereNotNull('longitude')
            ->get()
            ->sortBy(fn (User $deliverer) => $this->distanceSquared(
                (float) $shopLatitude,
                (float) $shopLongitude,
                (float) $deliverer->latitude,
                (float) $deliverer->longitude,
            ))
            ->first();
    }

    private function distanceSquared(float $latA, float $lngA, float $latB, float $lngB): float
    {
        return (($latA - $latB) ** 2) + (($lngA - $lngB) ** 2);
    }

    private function shouldPaginate(Request $request): bool
    {
        return $request->hasAny(['page', 'per_page', 'paginate', 'q']);
    }

    private function perPage(Request $request, int $default = 20, int $max = 50): int
    {
        return min($max, max(1, (int) $request->query('per_page', $default)));
    }
}
