<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Cart;
use App\Models\DeliveryAssignment;
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
        $items = Cart::with('product.shop')->where('buyer_id', $request->user()->id)->get();
        return response()->json(['items' => $items]);
    }

    public function add(Request $request, Product $product): JsonResponse
    {
        abort_unless($request->user()->role === 'buyer', 403, 'Only buyers can add to cart.');
        $data = $request->validate(['quantity' => ['required', 'integer', 'min:1']]);
        $item = Cart::updateOrCreate(['buyer_id' => $request->user()->id, 'product_id' => $product->id], ['quantity' => $data['quantity']]);
        return response()->json(['item' => $item->load('product')], 201);
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
        $items = Cart::with('product.shop')->where('buyer_id', $request->user()->id)->get();
        abort_if($items->isEmpty(), 422, 'Cart is empty.');

        $order = DB::transaction(function () use ($request, $items, $data) {
            $first = $items->first()->product;
            $subtotal = $items->sum(fn ($item) => ($item->product->discount_price ?? $item->product->price) * $item->quantity);
            $delivery = $items->sum(fn ($item) => $item->product->delivery_price * $item->quantity);
            $code = $this->deliveryCode();
            $order = Order::create([
                'reference' => 'DL-'.now()->format('YmdHis').'-'.Str::upper(Str::random(5)),
                'buyer_id' => $request->user()->id,
                'seller_id' => $first->seller_id,
                'shop_id' => $first->shop_id,
                'delivery_address' => $data['delivery_address'] ?: $request->user()->address,
                'subtotal' => $subtotal,
                'delivery_total' => $delivery,
                'grand_total' => $subtotal + $delivery,
                'delivery_code_hash' => Hash::make($code),
                'delivery_code_demo' => $code,
            ]);
            foreach ($items as $item) {
                $unit = $item->product->discount_price ?? $item->product->price;
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
            Cart::where('buyer_id', $request->user()->id)->delete();
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
        $assignmentId = (string) $order->deliveryAssignment?->id;
        User::where('role', 'deliverer')
            ->where('is_active', true)
            ->whereNotNull('fcm_token')
            ->get()
            ->each(fn ($deliverer) => $fcm->sendToUser($deliverer, 'New delivery request', 'Open DiscountLink to accept order '.$order->reference.'.', [
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
}
