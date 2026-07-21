<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Payment;
use App\Models\Product;
use App\Models\ProductCampaign;
use App\Services\ClickPesaService;
use App\Services\ProductCampaignService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;
use Throwable;

class ProductCampaignController extends Controller
{
    public function index(Request $request, ProductCampaignService $campaigns): JsonResponse
    {
        abort_unless($request->user()->role === 'seller', 403, 'Only sellers can manage product campaigns.');

        $search = trim((string) $request->query('q'));
        $query = ProductCampaign::with(['product.shop', 'payment'])
            ->where('seller_id', $request->user()->id)
            ->when($request->filled('channel'), fn ($builder) => $builder->where('channel', $request->query('channel')))
            ->when($request->filled('status'), fn ($builder) => $builder->where('status', $request->query('status')))
            ->when($search !== '', fn ($builder) => $builder->where(fn ($campaignQuery) => $campaignQuery
                ->where('reference', 'like', "%{$search}%")
                ->orWhere('status', 'like', "%{$search}%")
                ->orWhereHas('product', fn ($productQuery) => $productQuery->where('name', 'like', "%{$search}%"))))
            ->latest();

        return response()->json([
            'campaigns' => $query->paginate(min(50, max(1, (int) $request->query('per_page', 20))))->withQueryString(),
            'pricing' => $campaigns->pricing(),
        ]);
    }

    public function store(
        Request $request,
        ProductCampaignService $campaigns,
        ClickPesaService $clickPesa,
    ): JsonResponse {
        abort_unless($request->user()->role === 'seller', 403, 'Only sellers can create product campaigns.');

        $data = $request->validate([
            'product_id' => ['required', 'integer', 'exists:products,id'],
            'channel' => ['required', Rule::in(['sms', 'fcm'])],
            'payment_phone' => ['nullable', 'string', 'regex:/^\d{12}$/'],
        ], [
            'payment_phone.regex' => 'Payment phone number must contain exactly 12 digits, for example 255700000001.',
        ]);

        $product = Product::with('shop')->findOrFail($data['product_id']);
        abort_unless($product->seller_id === $request->user()->id, 403, 'You can campaign only your own products.');
        abort_unless($product->is_active && $product->shop?->is_active, 422, 'Only active products from active shops can be campaigned.');

        if ($campaigns->unitPrice($data['channel']) > 0) {
            abort_unless(
                $request->user()->phone && $request->user()->phone_verified_at,
                422,
                'Verify your seller phone before paying for a campaign.',
            );
        }

        ['campaign' => $campaign, 'payment' => $payment] = $campaigns->create(
            $request->user(),
            $product,
            $data['channel'],
            $data['payment_phone'] ?? null,
        );

        $ussdPush = null;
        if ($payment) {
            try {
                $ussdPush = $clickPesa->requestUssdPush($payment);
                $campaigns->syncPaymentStatus($payment->fresh());
            } catch (Throwable $error) {
                $campaign->update(['status' => 'payment_failed']);
                throw $this->paymentRequestException($error);
            }
        }

        return response()->json([
            'message' => $payment
                ? 'Campaign saved. Approve the ClickPesa payment prompt; delivery starts only after payment confirmation.'
                : 'Campaign queued. The configured channel price is zero, so no payment is required.',
            'campaign' => $campaign->fresh(['product.shop', 'payment']),
            'payment' => $payment?->fresh(),
            'ussd_push' => $ussdPush,
        ], 202);
    }

    public function resendPaymentPrompt(
        Request $request,
        Payment $payment,
        ClickPesaService $clickPesa,
        ProductCampaignService $campaigns,
    ): JsonResponse {
        abort_unless($payment->type === 'product_campaign' && $payment->user_id === $request->user()->id, 403);
        abort_unless($request->user()->role === 'seller', 403, 'Only sellers can pay for product campaigns.');
        abort_if(in_array($payment->status, ['paid', 'success', 'completed'], true), 422, 'This campaign payment is already complete.');
        abort_unless($payment->phone, 422, 'This campaign payment does not have a phone number.');

        $campaign = ProductCampaign::where('payment_id', $payment->id)
            ->where('seller_id', $request->user()->id)
            ->firstOrFail();
        $campaign->update(['status' => 'pending_payment']);

        try {
            $ussdPush = $clickPesa->requestUssdPush($payment);
            $campaigns->syncPaymentStatus($payment->fresh());
        } catch (Throwable $error) {
            $campaign->update(['status' => 'payment_failed']);
            throw $this->paymentRequestException($error);
        }

        return response()->json([
            'message' => 'Campaign payment request resent. Delivery starts only after payment confirmation.',
            'campaign' => $campaign->fresh(['product.shop', 'payment']),
            'payment' => $payment->fresh(),
            'ussd_push' => $ussdPush,
        ]);
    }

    private function paymentRequestException(Throwable $error): ValidationException
    {
        if ($error instanceof ValidationException) {
            return $error;
        }

        report($error);

        return ValidationException::withMessages([
            'payment' => 'Campaign payment request could not be sent. Check the payment provider configuration and try again.',
        ]);
    }
}
