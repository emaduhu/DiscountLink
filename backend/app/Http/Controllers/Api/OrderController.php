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

        return response()->json(['orders' => $orders]);
    }
}
