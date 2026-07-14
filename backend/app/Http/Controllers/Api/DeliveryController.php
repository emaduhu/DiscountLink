<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Jobs\ProcessClickPesaPayment;
use App\Models\DeliveryAssignment;
use App\Models\Payment;
use App\Models\Product;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class DeliveryController extends Controller
{
    public function available(Request $request): JsonResponse
    {
        abort_unless($request->user()->role === 'deliverer', 403);
        $isAvailable = (bool) $request->user()->is_available;
        $jobs = DeliveryAssignment::with('order.items', 'order.buyer', 'order.shop', 'deliverer')
            ->whereIn('status', ['broadcast', 'accepted'])
            ->where(function ($query) use ($request, $isAvailable) {
                $query->where(fn ($builder) => $builder->where('status', 'accepted')->where('deliverer_id', $request->user()->id));

                if ($isAvailable) {
                    $query->orWhere(fn ($builder) => $builder
                        ->where('status', 'broadcast')
                        ->where(fn ($nested) => $nested->whereNull('deliverer_id')->orWhere('deliverer_id', $request->user()->id)));
                }
            })
            ->when(trim((string) $request->query('q')), function ($query, string $search) {
                $query->where(fn ($builder) => $builder
                    ->where('status', 'like', "%{$search}%")
                    ->orWhereHas('order', fn ($orderQuery) => $orderQuery
                        ->where('reference', 'like', "%{$search}%")
                        ->orWhere('delivery_address', 'like', "%{$search}%")
                        ->orWhereHas('shop', fn ($shopQuery) => $shopQuery->where('name', 'like', "%{$search}%"))
                        ->orWhereHas('buyer', fn ($buyerQuery) => $buyerQuery->where('name', 'like', "%{$search}%"))));
            })
            ->latest();

        $jobs = $this->shouldPaginate($request)
            ? $jobs->paginate($this->perPage($request))
            : $jobs->get();

        $jobs->each(function (DeliveryAssignment $assignment) use ($request) {
            $buyer = $assignment->order?->buyer;
            if (! $buyer) {
                return;
            }

            $buyer->setAttribute(
                'call_phone',
                $assignment->status === 'accepted' && $assignment->deliverer_id === $request->user()->id
                    ? $buyer->phone
                    : null
            );
            $buyer->makeHidden(['phone', 'email']);
        });

        return response()->json([
            'jobs' => $jobs,
            'is_available' => $isAvailable,
        ]);
    }

    public function updateAvailability(Request $request): JsonResponse
    {
        abort_unless($request->user()->role === 'deliverer', 403);

        $data = $request->validate([
            'is_available' => ['required', 'boolean'],
        ]);

        $request->user()->update(['is_available' => $data['is_available']]);

        return response()->json([
            'message' => $data['is_available'] ? 'You are available for delivery jobs.' : 'You are unavailable for new delivery jobs.',
            'user' => $request->user()->fresh(),
            'is_available' => (bool) $request->user()->fresh()->is_available,
        ]);
    }

    public function accept(Request $request, DeliveryAssignment $assignment): JsonResponse
    {
        abort_unless($request->user()->role === 'deliverer', 403);
        abort_if($assignment->deliverer_id && $assignment->deliverer_id !== $request->user()->id, 409, 'Delivery already accepted.');
        abort_unless($request->user()->phone_verified_at, 422, 'Verify your phone before accepting delivery jobs.');
        abort_unless($request->user()->is_available || $assignment->deliverer_id === $request->user()->id, 422, 'Turn on availability before accepting new delivery jobs.');
        $assignment->update(['deliverer_id' => $request->user()->id, 'status' => 'accepted', 'accepted_at' => now()]);
        $assignment->order->update(['status' => 'out_for_delivery']);
        $assignment->load('order.items', 'order.buyer', 'deliverer');
        $assignment->order->buyer?->setAttribute('call_phone', $assignment->order->buyer?->phone);
        $assignment->order->buyer?->makeHidden(['phone', 'email']);

        return response()->json(['assignment' => $assignment]);
    }

    public function updateLocation(Request $request, DeliveryAssignment $assignment): JsonResponse
    {
        abort_unless($assignment->deliverer_id === $request->user()->id, 403);
        abort_unless($assignment->status === 'accepted', 422, 'Only accepted deliveries can be tracked.');

        $data = $request->validate([
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
        ]);

        $assignment->update([
            'deliverer_latitude' => $data['latitude'],
            'deliverer_longitude' => $data['longitude'],
            'location_updated_at' => now(),
        ]);

        $request->user()->update([
            'latitude' => $data['latitude'],
            'longitude' => $data['longitude'],
        ]);

        return response()->json(['assignment' => $assignment->fresh('order.items', 'deliverer')]);
    }

    public function complete(Request $request, DeliveryAssignment $assignment): JsonResponse
    {
        abort_unless($assignment->deliverer_id === $request->user()->id, 403);
        $data = $request->validate([
            'delivery_code' => ['required', 'string', 'regex:/^(?!.*(.).*\\1)\\d{4}$/'],
        ], [
            'delivery_code.regex' => 'Enter the 4 unique digits shown to the buyer.',
        ]);
        $assignment->loadMissing('order.seller');
        $order = $assignment->order;

        abort_if($assignment->status === 'completed' || $order->status === 'delivered', 409, 'Delivery is already completed.');
        abort_unless(Hash::check($data['delivery_code'], $order->delivery_code_hash), 422, 'Invalid delivery code.');
        abort_unless($request->user()->phone && $request->user()->phone_verified_at, 422, 'Verify the deliverer payout phone before completing delivery.');
        abort_unless($order->seller?->phone && $order->seller?->phone_verified_at, 422, 'Seller payout phone is not verified.');

        [$sellerPayment, $deliveryPayment] = DB::transaction(function () use ($assignment, $request) {
            $lockedAssignment = DeliveryAssignment::query()
                ->whereKey($assignment->id)
                ->lockForUpdate()
                ->firstOrFail();
            $lockedOrder = $lockedAssignment->order()
                ->with('seller', 'items')
                ->lockForUpdate()
                ->firstOrFail();

            abort_if($lockedAssignment->status === 'completed' || $lockedOrder->status === 'delivered', 409, 'Delivery is already completed.');

            $lockedAssignment->update(['status' => 'completed', 'completed_at' => now()]);
            $lockedOrder->update(['status' => 'delivered', 'delivered_at' => now()]);

            $lockedOrder->items
                ->groupBy('product_id')
                ->each(function ($items, int $productId) {
                    $product = Product::query()->whereKey($productId)->lockForUpdate()->first();
                    if (! $product) {
                        return;
                    }

                    $quantitySold = (int) $items->sum('quantity');
                    $product->forceFill([
                        'stock' => max(0, (int) $product->stock - $quantitySold),
                    ])->save();
                });

            $sellerPayment = Payment::create([
                'order_id' => $lockedOrder->id,
                'user_id' => $lockedOrder->seller_id,
                'type' => 'seller_disbursement',
                'amount' => $lockedOrder->subtotal,
                'phone' => $lockedOrder->seller->phone,
            ]);

            $deliveryPayment = Payment::create([
                'order_id' => $lockedOrder->id,
                'user_id' => $request->user()->id,
                'type' => 'deliverer_disbursement',
                'amount' => $lockedOrder->delivery_total,
                'phone' => $request->user()->phone,
            ]);

            return [$sellerPayment, $deliveryPayment];
        });

        ProcessClickPesaPayment::queueDisbursement($sellerPayment);
        ProcessClickPesaPayment::queueDisbursement($deliveryPayment);

        return response()->json([
            'assignment' => $assignment->fresh('order'),
            'seller_payment' => $sellerPayment->fresh(),
            'delivery_payment' => $deliveryPayment->fresh(),
            'seller_disbursement' => ['status' => 'queued'],
            'delivery_disbursement' => ['status' => 'queued'],
            'message' => 'Delivery code confirmed. Seller and delivery payments have been queued.',
        ]);
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
