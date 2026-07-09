<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Order;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class OrderController extends Controller
{
    public function active(Request $request): JsonResponse
    {
        abort_unless($request->user()->role === 'buyer', 403);

        $orders = Order::with([
            'items',
            'shop',
            'deliveryAssignment.deliverer',
        ])
            ->where('buyer_id', $request->user()->id)
            ->whereNotIn('status', ['delivered', 'cancelled'])
            ->latest()
            ->get();

        $orders->each(function (Order $order) {
            $order->setAttribute('delivery_code', $order->delivery_code_demo);
            $order->setAttribute(
                'delivery_code_notice',
                'Share this code only after the order arrives. It releases seller and delivery payments.'
            );
        });

        return response()->json(['orders' => $orders]);
    }
}
