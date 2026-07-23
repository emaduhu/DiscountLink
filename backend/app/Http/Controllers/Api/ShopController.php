<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AppSetting;
use App\Models\Cart;
use App\Models\DelivererInvitation;
use App\Models\Payment;
use App\Models\Product;
use App\Models\Shop;
use App\Services\ClickPesaService;
use App\Services\OtpProviderService;
use App\Services\ProductCampaignService;
use App\Services\ProductMediaService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\ValidationException;
use Throwable;

class ShopController extends Controller
{
    public function categories(): JsonResponse
    {
        return response()->json(['categories' => $this->configuredCategories()]);
    }

    public function store(Request $request, ClickPesaService $clickPesa): JsonResponse
    {
        abort_unless($request->user()->role === 'seller', 403, 'Only sellers can open shops.');
        $this->normalizeRegistrationPaymentPhone($request);
        $data = $request->validate([
            'name' => ['required', 'string', 'max:160'],
            'category' => ['nullable', 'string', 'max:100'],
            'categories' => ['nullable', 'array', 'min:1'],
            'categories.*' => ['required', 'string', 'max:100'],
            'address' => ['nullable', 'string', 'max:255'],
            'latitude' => ['nullable', 'numeric'],
            'longitude' => ['nullable', 'numeric'],
            'opening_time' => ['nullable', 'required_with:closing_time', 'date_format:H:i'],
            'closing_time' => ['nullable', 'required_with:opening_time', 'date_format:H:i'],
            'timezone' => ['nullable', 'timezone:all'],
            'registration_payment_phone' => ['nullable', 'string', 'regex:/^\d{12}$/'],
        ], [
            'registration_payment_phone.regex' => 'Payment phone number must contain exactly 12 digits, for example 255700000001.',
        ]);
        $categories = collect($data['categories'] ?? [$data['category'] ?? null])
            ->filter()
            ->map(fn (string $category) => trim($category))
            ->filter()
            ->unique()
            ->values();
        abort_if($categories->isEmpty(), 422, 'Choose at least one shop category.');
        $this->abortForUnknownCategories($categories);
        $data['address'] = ($data['address'] ?? null) ?: $request->user()->address;
        abort_if(! $data['address'], 422, 'Add a shop address or update your seller address.');
        $data['category'] = $categories->first();
        $data['categories'] = $categories->all();
        $this->abortForMatchingBusinessHours($data);
        $data['timezone'] = $data['timezone'] ?? Shop::DEFAULT_TIMEZONE;
        $registrationPaymentPhone = $data['registration_payment_phone'] ?? null;
        unset($data['registration_payment_phone']);

        $feeAmount = $this->shopRegistrationFeeAmount();
        if ($feeAmount <= 0) {
            $shop = Shop::create($data + [
                'seller_id' => $request->user()->id,
                'is_active' => true,
                'registration_fee_amount' => 0,
                'registration_fee_status' => 'waived',
            ]);

            return response()->json([
                'message' => 'Shop created. Registration fee is currently waived.',
                'shop' => $shop,
                'registration_fee' => $this->registrationFeePayload(),
            ], 201);
        }

        abort_unless($request->user()->phone && $request->user()->phone_verified_at, 422, 'Verify your seller phone before paying the shop registration fee.');

        $shop = Shop::create($data + [
            'seller_id' => $request->user()->id,
            'is_active' => false,
            'registration_fee_amount' => $feeAmount,
            'registration_fee_status' => 'pending',
        ]);
        $payment = Payment::create([
            'shop_id' => $shop->id,
            'user_id' => $request->user()->id,
            'type' => 'shop_registration_fee',
            'provider' => 'clickpesa',
            'status' => 'pending',
            'amount' => $feeAmount,
            'phone' => $registrationPaymentPhone ?: $request->user()->phone,
            'payload' => ['shop_id' => $shop->id],
        ]);
        $shop->update(['registration_fee_payment_id' => $payment->id]);

        try {
            $ussdPush = $clickPesa->requestUssdPush($payment);
        } catch (Throwable $error) {
            $this->syncRegistrationFeeStatus($shop, $payment->fresh());

            throw $this->paymentRequestException($error);
        }
        $this->syncRegistrationFeeStatus($shop, $payment->fresh());

        return response()->json([
            'message' => 'Shop saved. The ClickPesa registration fee request has been sent.',
            'shop' => $shop->fresh('registrationFeePayment'),
            'payment' => $payment->fresh(),
            'ussd_push' => $ussdPush,
            'registration_fee' => $this->registrationFeePayload(),
        ], 202);
    }

    public function mine(Request $request): JsonResponse
    {
        $shops = $request->user()->shops()
            ->with([
                'registrationFeePayment',
                'products' => fn ($query) => $query
                    ->withAvg('ratings', 'rating')
                    ->withCount('ratings')
                    ->where('is_active', true)
                    ->when(trim((string) $request->query('product_q')), fn ($productQuery, string $search) => $productQuery
                        ->where(fn ($builder) => $builder
                            ->where('name', 'like', "%{$search}%")
                            ->orWhere('description', 'like', "%{$search}%")))
                    ->latest(),
            ])
            ->when(trim((string) $request->query('q')), function ($query, string $search) {
                $query->where(fn ($builder) => $builder
                    ->where('name', 'like', "%{$search}%")
                    ->orWhere('category', 'like', "%{$search}%")
                    ->orWhere('address', 'like', "%{$search}%")
                    ->orWhereHas('products', fn ($productQuery) => $productQuery
                        ->where('name', 'like', "%{$search}%")
                        ->orWhere('description', 'like', "%{$search}%")));
            })
            ->latest();

        return response()->json([
            'shops' => $this->shouldPaginate($request)
                ? $shops->paginate($this->perPage($request))
                : $shops->get(),
            'registration_fee' => $this->registrationFeePayload(),
            'deliverer_invitations' => DelivererInvitation::where('seller_id', $request->user()->id)
                ->latest()
                ->limit(20)
                ->get(),
        ]);
    }

    public function resendRegistrationFeePayment(
        Request $request,
        Payment $payment,
        ClickPesaService $clickPesa,
    ): JsonResponse {
        abort_unless($request->user()->role === 'seller', 403, 'Only sellers can pay shop registration fees.');
        abort_unless(
            $payment->type === 'shop_registration_fee' && $payment->user_id === $request->user()->id,
            403,
        );
        abort_if($payment->isPaid(), 422, 'This shop registration payment is already complete.');
        abort_unless($payment->phone, 422, 'This shop registration payment does not have a phone number.');

        $shop = $payment->shop;
        abort_unless(
            $shop
                && ! $shop->trashed()
                && $shop->seller_id === $request->user()->id
                && (int) $shop->registration_fee_payment_id === $payment->id,
            404,
        );
        abort_if(
            in_array($shop->registration_fee_status, ['paid', 'waived'], true),
            422,
            'This shop registration fee is already complete.',
        );

        try {
            $ussdPush = $clickPesa->requestUssdPush($payment);
        } catch (Throwable $error) {
            $this->syncRegistrationFeeStatus($shop, $payment->fresh());

            throw $this->paymentRequestException($error);
        }

        $payment->refresh();
        $this->syncRegistrationFeeStatus($shop, $payment);

        return response()->json([
            'message' => $this->registrationPaymentRequestMessage($payment, $ussdPush),
            'shop' => $shop->fresh('registrationFeePayment'),
            'payment' => $payment,
            'ussd_push' => $ussdPush,
        ]);
    }

    public function inviteDeliverer(Request $request, OtpProviderService $otp): JsonResponse
    {
        abort_unless($request->user()->role === 'seller', 403, 'Only sellers can invite deliverers.');

        $data = $request->validate([
            'name' => ['nullable', 'string', 'max:160'],
            'phone' => ['required', 'string', 'max:30'],
        ]);

        $phone = preg_replace('/[\s-]+/', '', $data['phone']);
        abort_if($phone === '', 422, 'Enter the deliverer phone number.');
        $name = trim($data['name'] ?? '') ?: null;
        $playStoreUrl = config('services.discountlink.play_store_url');
        $appStoreUrl = config('services.discountlink.app_store_url');
        $sellerName = $request->user()->name ?: 'A DiscountLink seller';
        $message = "{$sellerName} invited you to join Vigour Deals as a deliverer. Download the app: Android {$playStoreUrl} iPhone {$appStoreUrl}. Register as Deliverer and get ready for operations.";
        $sent = false;
        $providerReference = null;

        try {
            $providerReference = $otp->sendMessage($phone, $message);
            $sent = true;
        } catch (Throwable $error) {
            Log::warning('DiscountLink deliverer invite could not be sent.', [
                'seller_id' => $request->user()->id,
                'phone' => $phone,
                'error' => $error->getMessage(),
            ]);
        }

        $invitation = DelivererInvitation::create([
            'seller_id' => $request->user()->id,
            'name' => $name,
            'phone' => $phone,
            'message' => $message,
            'provider_reference' => $providerReference,
            'sent_at' => $sent ? now() : null,
        ]);

        return response()->json([
            'message' => $sent ? 'Deliverer invitation sent.' : 'Deliverer saved, but the invite message could not be sent.',
            'sent' => $sent,
            'invitation' => $invitation,
        ], $sent ? 201 : 202);
    }

    public function update(Request $request, Shop $shop): JsonResponse
    {
        abort_unless($shop->seller_id === $request->user()->id, 403);
        $data = $request->validate([
            'name' => ['required', 'string', 'max:160'],
            'category' => ['nullable', 'string', 'max:100'],
            'categories' => ['nullable', 'array', 'min:1'],
            'categories.*' => ['required', 'string', 'max:100'],
            'address' => ['nullable', 'string', 'max:255'],
            'latitude' => ['nullable', 'numeric'],
            'longitude' => ['nullable', 'numeric'],
            'opening_time' => ['nullable', 'required_with:closing_time', 'date_format:H:i'],
            'closing_time' => ['nullable', 'required_with:opening_time', 'date_format:H:i'],
            'timezone' => ['nullable', 'timezone:all'],
        ]);
        $categories = collect($data['categories'] ?? [$data['category'] ?? null])
            ->filter()
            ->map(fn (string $category) => trim($category))
            ->filter()
            ->unique()
            ->values();
        abort_if($categories->isEmpty(), 422, 'Choose at least one shop category.');
        $this->abortForUnknownCategories($categories);
        $data['category'] = $categories->first();
        $data['categories'] = $categories->all();
        $this->abortForMatchingBusinessHours($data);
        if (array_key_exists('timezone', $data) && $data['timezone'] === null) {
            unset($data['timezone']);
        }
        $shop->update($data);

        return response()->json(['shop' => $shop->fresh('products')]);
    }

    public function updateHours(Request $request, Shop $shop): JsonResponse
    {
        abort_unless($shop->seller_id === $request->user()->id, 403);
        $data = $request->validate([
            'opening_time' => ['present', 'nullable', 'required_with:closing_time', 'date_format:H:i'],
            'closing_time' => ['present', 'nullable', 'required_with:opening_time', 'date_format:H:i'],
            'timezone' => ['nullable', 'timezone:all'],
        ]);
        $this->abortForMatchingBusinessHours($data);
        if (array_key_exists('timezone', $data) && $data['timezone'] === null) {
            unset($data['timezone']);
        }
        $shop->update($data);

        return response()->json([
            'message' => $shop->opening_time === null
                ? 'Shop hours removed. The shop will remain open while active.'
                : 'Shop opening and closing times updated.',
            'shop' => $shop->fresh(),
        ]);
    }

    public function destroy(Request $request, Shop $shop): JsonResponse
    {
        abort_unless($request->user()->role === 'seller', 403, 'Only sellers can delete shops.');
        abort_unless($shop->seller_id === $request->user()->id, 403);

        DB::transaction(function () use ($shop) {
            $lockedShop = Shop::query()
                ->whereKey($shop->id)
                ->lockForUpdate()
                ->firstOrFail();
            $productIds = $lockedShop->products()
                ->lockForUpdate()
                ->pluck('id');

            if ($productIds->isNotEmpty()) {
                Cart::whereIn('product_id', $productIds)->delete();
            }

            $lockedShop->update(['is_active' => false]);
            $lockedShop->delete();
        });

        return response()->json([
            'message' => 'Shop deleted. Its products are no longer available.',
        ]);
    }

    public function product(
        Request $request,
        Shop $shop,
        ProductMediaService $media,
        ProductCampaignService $campaigns,
    ): JsonResponse {
        abort_unless($shop->seller_id === $request->user()->id, 403);
        abort_unless($shop->is_active, 422, 'Pay the shop registration fee before adding products.');
        $data = $request->validate([
            'name' => ['required', 'string', 'max:180'],
            'description' => ['nullable', 'string'],
            'price' => ['required', 'numeric', 'min:0'],
            'discount_price' => ['nullable', 'numeric', 'min:0'],
            'discount_percent' => ['nullable', 'numeric', 'min:0', 'max:100'],
            'delivery_price' => ['required', 'numeric', 'min:0'],
            'images' => ['required_without:product_images', 'prohibits:product_images', 'array', 'size:3'],
            'images.*' => ['required', 'string', 'max:2048'],
            'product_images' => ['required_without:images', 'prohibits:images', 'array', 'size:3'],
            'product_images.*' => ['required', 'image', 'mimes:jpg,jpeg,png,webp', 'max:5120', 'dimensions:max_width=4096,max_height=4096'],
            'product_videos' => ['nullable', 'array', 'max:2'],
            'product_videos.*' => ['required', 'file', 'mimes:mp4,mov,webm', 'mimetypes:video/mp4,video/quicktime,video/webm', 'max:51200'],
            'stock' => ['required', 'integer', 'min:0'],
        ], [
            'images.size' => 'A product must have exactly 3 images.',
            'product_images.size' => 'Upload exactly 3 product images.',
            'product_images.*.max' => 'Each product image must be 5 MB or smaller.',
            'product_videos.max' => 'A product can have at most 2 videos.',
            'product_videos.*.max' => 'Each product video must be 50 MB or smaller.',
        ]);
        $imageFiles = $request->hasFile('product_images') ? array_values($request->file('product_images')) : null;
        $imageUrls = array_key_exists('images', $data) ? $data['images'] : null;
        $videoFiles = $request->hasFile('product_videos') ? array_values($request->file('product_videos')) : [];
        unset($data['images'], $data['product_images'], $data['product_videos']);
        $effective = $data['discount_price'] ?? round($data['price'] * (1 - (($data['discount_percent'] ?? 0) / 100)), 2);
        $data['auto_total'] = $effective + $data['delivery_price'];
        $product = Product::create($data + [
            'shop_id' => $shop->id,
            'seller_id' => $request->user()->id,
            'images' => $imageUrls ?? [],
        ]);

        try {
            $product = $media->synchronize($product, [], $imageFiles, $imageUrls, $videoFiles);
        } catch (Throwable $error) {
            $product->delete();

            throw $error;
        }

        try {
            $campaigns->announceNewProduct($product);
        } catch (Throwable $error) {
            report($error);
        }

        return response()->json(['product' => $product], 201);
    }

    public function updateProduct(Request $request, Product $product, ProductMediaService $media): JsonResponse
    {
        abort_unless($product->seller_id === $request->user()->id, 403);
        $data = $request->validate([
            'name' => ['required', 'string', 'max:180'],
            'description' => ['nullable', 'string'],
            'price' => ['required', 'numeric', 'min:0'],
            'discount_price' => ['nullable', 'numeric', 'min:0'],
            'discount_percent' => ['nullable', 'numeric', 'min:0', 'max:100'],
            'delivery_price' => ['required', 'numeric', 'min:0'],
            'images' => ['nullable', 'prohibits:product_images', 'array', 'size:3'],
            'images.*' => ['required', 'string', 'max:2048'],
            'product_images' => ['nullable', 'prohibits:images', 'array', 'size:3'],
            'product_images.*' => ['required', 'image', 'mimes:jpg,jpeg,png,webp', 'max:5120', 'dimensions:max_width=4096,max_height=4096'],
            'product_videos' => ['nullable', 'array', 'max:2'],
            'product_videos.*' => ['required', 'file', 'mimes:mp4,mov,webm', 'mimetypes:video/mp4,video/quicktime,video/webm', 'max:51200'],
            'clear_videos' => ['sometimes', 'boolean'],
            'stock' => ['required', 'integer', 'min:0'],
        ], [
            'images.size' => 'A product must have exactly 3 images.',
            'product_images.size' => 'Upload exactly 3 replacement product images.',
            'product_images.*.max' => 'Each product image must be 5 MB or smaller.',
            'product_videos.max' => 'A product can have at most 2 videos.',
            'product_videos.*.max' => 'Each product video must be 50 MB or smaller.',
        ]);
        abort_if($request->boolean('clear_videos') && $request->hasFile('product_videos'), 422, 'Do not upload videos while clearing them.');

        $imageFiles = $request->hasFile('product_images') ? array_values($request->file('product_images')) : null;
        $imageUrls = array_key_exists('images', $data) && is_array($data['images']) ? $data['images'] : null;
        $videoFiles = $request->boolean('clear_videos')
            ? []
            : ($request->hasFile('product_videos') ? array_values($request->file('product_videos')) : null);
        $effective = $data['discount_price'] ?? round($data['price'] * (1 - (($data['discount_percent'] ?? 0) / 100)), 2);
        $data['auto_total'] = $effective + $data['delivery_price'];
        unset($data['images'], $data['product_images'], $data['product_videos'], $data['clear_videos']);
        $product = $media->synchronize($product, $data, $imageFiles, $imageUrls, $videoFiles);

        return response()->json(['product' => $product]);
    }

    public function destroyProduct(Request $request, Product $product, ProductMediaService $media): JsonResponse
    {
        abort_unless($product->seller_id === $request->user()->id, 403);
        $media->deactivate($product);

        return response()->json(['message' => 'Product removed.']);
    }

    /**
     * @return array<int, string>
     */
    private function configuredCategories(): array
    {
        $raw = AppSetting::get('shop_categories', implode("\n", $this->defaultCategories()));

        return collect(preg_split('/[\r\n,]+/', $raw ?: '') ?: [])
            ->map(fn (string $category) => trim($category))
            ->filter()
            ->unique()
            ->values()
            ->all() ?: $this->defaultCategories();
    }

    /**
     * @param  Collection<int, string>  $categories
     */
    private function abortForUnknownCategories($categories): void
    {
        $allowed = $this->configuredCategories();
        $unknown = $categories->reject(fn (string $category) => in_array($category, $allowed, true));
        abort_if($unknown->isNotEmpty(), 422, 'Choose categories configured by the backend.');
    }

    /**
     * @param  array<string, mixed>  $data
     */
    private function abortForMatchingBusinessHours(array $data): void
    {
        $opening = $data['opening_time'] ?? null;
        $closing = $data['closing_time'] ?? null;

        abort_if($opening !== null && $opening === $closing, 422, 'Opening and closing times must be different.');
    }

    private function normalizeRegistrationPaymentPhone(Request $request): void
    {
        $phone = $request->input('registration_payment_phone');
        if (! is_string($phone)) {
            return;
        }

        $phone = trim($phone);
        if (str_starts_with($phone, '+')) {
            $phone = substr($phone, 1);
        }

        $request->merge([
            'registration_payment_phone' => preg_replace('/[\s-]+/', '', $phone) ?? '',
        ]);
    }

    private function syncRegistrationFeeStatus(Shop $shop, Payment $payment): void
    {
        $status = strtolower($payment->status);

        if ($payment->isPaid()) {
            $shop->update([
                'is_active' => true,
                'registration_fee_status' => 'paid',
                'registration_fee_payment_id' => $payment->id,
                'registration_paid_at' => $shop->registration_paid_at ?: now(),
            ]);

            return;
        }

        if (in_array($status, ['failed', 'cancelled', 'canceled', 'expired'], true)) {
            $shop->update([
                'is_active' => false,
                'registration_fee_status' => 'failed',
                'registration_fee_payment_id' => $payment->id,
            ]);

            return;
        }

        $shop->update([
            'is_active' => false,
            'registration_fee_status' => 'processing',
            'registration_fee_payment_id' => $payment->id,
        ]);
    }

    /**
     * @param  array<string, mixed>  $ussdPush
     */
    private function registrationPaymentRequestMessage(Payment $payment, array $ussdPush): string
    {
        $reference = $ussdPush['reference']
            ?? $payment->provider_reference
            ?? $ussdPush['orderReference']
            ?? '-';
        $channel = data_get($ussdPush, 'initiate.channel') ?: data_get($ussdPush, 'channel');

        return trim(
            'Shop registration payment request sent to '.$payment->phone
            .'. Reference: '.$reference
            .($channel ? '. Channel: '.$channel : '')
            .'. Check your phone and approve the USSD prompt.',
        );
    }

    private function paymentRequestException(Throwable $error): ValidationException
    {
        if ($error instanceof ValidationException) {
            return $error;
        }

        report($error);

        return ValidationException::withMessages([
            'payment' => 'Shop registration payment request could not be sent. Check the payment provider configuration and try again.',
        ]);
    }

    private function shopRegistrationFeeAmount(): float
    {
        return max(0, round((float) AppSetting::get('shop_registration_fee_amount', '0'), 2));
    }

    private function registrationFeePayload(): array
    {
        $amount = $this->shopRegistrationFeeAmount();

        return [
            'amount' => $amount,
            'currency' => 'TZS',
            'enabled' => $amount > 0,
        ];
    }

    /**
     * @return array<int, string>
     */
    private function defaultCategories(): array
    {
        return ['Electronics', 'Fashion', 'Groceries', 'Books', 'Art', 'Home', 'Other'];
    }

    private function shouldPaginate(Request $request): bool
    {
        return $request->hasAny(['page', 'per_page', 'paginate', 'q', 'product_q']);
    }

    private function perPage(Request $request, int $default = 20, int $max = 50): int
    {
        return min($max, max(1, (int) $request->query('per_page', $default)));
    }
}
