<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\DeliveryAssignment;
use App\Models\Payment;
use App\Services\ClickPesaService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class DeliveryController extends Controller
{
    public function available(Request $request): JsonResponse
    {
        abort_unless($request->user()->role === 'deliverer', 403);
        $jobs = DeliveryAssignment::with('order.items', 'order.buyer', 'order.shop', 'deliverer')
            ->whereIn('status', ['broadcast', 'accepted'])
            ->where(fn ($query) => $query->whereNull('deliverer_id')->orWhere('deliverer_id', $request->user()->id))
            ->latest()
            ->get();
        return response()->json(['jobs' => $jobs]);
    }

    public function accept(Request $request, DeliveryAssignment $assignment): JsonResponse
    {
        abort_unless($request->user()->role === 'deliverer', 403);
        abort_if($assignment->deliverer_id && $assignment->deliverer_id !== $request->user()->id, 409, 'Delivery already accepted.');
        abort_unless($request->user()->phone_verified_at, 422, 'Verify your phone before accepting delivery jobs.');
        $assignment->update(['deliverer_id' => $request->user()->id, 'status' => 'accepted', 'accepted_at' => now()]);
        $assignment->order->update(['status' => 'out_for_delivery']);
        return response()->json(['assignment' => $assignment->load('order.items', 'deliverer')]);
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

    public function complete(Request $request, DeliveryAssignment $assignment, ClickPesaService $clickPesa): JsonResponse
    {
        abort_unless($assignment->deliverer_id === $request->user()->id, 403);
        $data = $request->validate(['delivery_code' => ['required', 'string', 'size:6']]);
        abort_unless(Hash::check($data['delivery_code'], $assignment->order->delivery_code_hash), 422, 'Invalid delivery code.');

        $assignment->update(['status' => 'completed', 'completed_at' => now()]);
        $assignment->order->update(['status' => 'delivered', 'delivered_at' => now()]);
        $payment = Payment::create([
            'order_id' => $assignment->order_id,
            'user_id' => $request->user()->id,
            'type' => 'deliverer_disbursement',
            'amount' => $assignment->order->delivery_total,
            'phone' => $request->user()->phone,
        ]);
        $disbursement = $clickPesa->disburse($payment);
        return response()->json(['assignment' => $assignment->fresh('order'), 'payment' => $payment->fresh(), 'disbursement' => $disbursement]);
    }
}
