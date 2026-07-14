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
            ->when(trim((string) $request->query('q')), function ($query, string $search) {
                $query->where(fn ($builder) => $builder
                    ->where('reference', 'like', "%{$search}%")
                    ->orWhere('status', 'like', "%{$search}%")
                    ->orWhereHas('shop', fn ($shopQuery) => $shopQuery->where('name', 'like', "%{$search}%")));
            })
            ->latest();

        $orders = $this->shouldPaginate($request)
            ? $orders->paginate($this->perPage($request))
            : $orders->get();

        $orders->each(function (Order $order) {
            $order->setAttribute('delivery_code', $order->delivery_code_demo);
            $order->setAttribute(
                'delivery_code_notice',
                'Share this code only after the order arrives. It releases seller and delivery payments.'
            );
        });

        return response()->json(['orders' => $orders]);
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
