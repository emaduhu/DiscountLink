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
use App\Services\FcmService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class CartController extends Controller
{
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
        $items = Cart::with(['product.shop', 'discountLink'])->where('buyer_id', $request->user()->id)->get();
        $subtotal = $items->sum(fn ($item) => $this->cartUnitPrice($item) * $item->quantity);
        $delivery = $items->sum(fn ($item) => $item->product->delivery_price * $item->quantity);
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
        abort_unless($request->user()->role === 'buyer', 403, 'Only buyers can add to cart.');
        $data = $request->validate(['quantity' => ['required', 'integer', 'min:1']]);
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
        abort_unless($request->user()->role === 'buyer', 403, 'Only buyers can add discount links to cart.');
        $data = $request->validate(['quantity' => ['nullable', 'integer', 'min:1']]);
        $discountLink = DiscountLink::with('product')
            ->where('token', $token)
            ->firstOrFail();

        abort_unless($discountLink->buyer_id === $request->user()->id, 403, 'This discount link belongs to another buyer.');
        abort_unless($this->discountLinkIsValid($discountLink), 422, 'This discount link is expired or already used.');
        abort_unless($discountLink->product->is_active && $discountLink->product->stock > 0, 422, 'This product is no longer available.');

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
        abort_unless($request->user()->role === 'buyer', 403, 'Only buyers can remove cart items.');
        Cart::where('buyer_id', $request->user()->id)->where('product_id', $product->id)->delete();
        return response()->json(['message' => 'Item removed from cart.']);
    }

    public function checkout(Request $request, ClickPesaService $clickPesa, FcmService $fcm): JsonResponse
    {
        abort_unless($request->user()->role === 'buyer', 403);
        abort_unless($request->user()->phone_verified_at, 422, 'Verify your phone before payment.');
        $data = $request->validate(['delivery_address' => ['nullable', 'string', 'max:255'], 'phone' => ['nullable', 'string', 'max:30']]);
        $items = Cart::with(['product.shop', 'discountLink'])->where('buyer_id', $request->user()->id)->get();
        abort_if($items->isEmpty(), 422, 'Cart is empty.');

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
                'delivery_code_demo' => $code,
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
            'amount' => $order->grand_total,
            'phone' => $data['phone'] ?? $request->user()->phone,
        ]);
        $push = $clickPesa->requestUssdPush($payment);

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
        $loadedOrder = $order->load('items');
        $loadedOrder->setAttribute('delivery_code', $deliveryCode);

        return response()->json([
            'order' => $loadedOrder,
            'payment' => $payment->fresh(),
            'ussd_push' => $push,
            'delivery_code' => $deliveryCode,
            'delivery_code_demo' => $deliveryCode,
            'message' => 'Keep this buyer delivery code. Share it only after receiving the order to release seller and delivery payments.',
        ], 201);
    }

    private function cartUnitPrice(Cart $item): float
    {
        if ($item->unit_price_override !== null && $item->discountLink && $this->discountLinkIsValid($item->discountLink)) {
            return (float) $item->unit_price_override;
        }

        return (float) ($item->product->discount_price ?? $item->product->price);
    }

    private function discountLinkIsValid(DiscountLink $discountLink): bool
    {
        return $discountLink->used_at === null
            && ($discountLink->expires_at === null || $discountLink->expires_at->isFuture());
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
}
