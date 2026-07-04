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
            $code = (string) random_int(100000, 999999);
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
            DeliveryAssignment::create(['order_id' => $order->id]);
            Cart::where('buyer_id', $request->user()->id)->delete();
            $order->setAttribute('plain_delivery_code', $code);
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
        User::where('role', 'deliverer')->whereNotNull('phone_verified_at')->get()->each(fn ($deliverer) => $fcm->sendToUser($deliverer, 'New delivery', 'A paid order needs delivery.', ['order_id' => $order->id]));

        return response()->json(['order' => $order->load('items'), 'payment' => $payment->fresh(), 'ussd_push' => $push, 'delivery_code_demo' => $order->plain_delivery_code], 201);
    }
}
