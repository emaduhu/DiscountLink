<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Jobs\ProcessClickPesaPayment;
use App\Models\AppSetting;
use App\Models\DelivererInvitation;
use App\Models\Payment;
use App\Models\Product;
use App\Models\Shop;
use App\Services\OtpProviderService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;

class ShopController extends Controller
{
    public function categories(): JsonResponse
    {
        return response()->json(['categories' => $this->configuredCategories()]);
    }

    public function store(Request $request): JsonResponse
    {
        abort_unless($request->user()->role === 'seller', 403, 'Only sellers can open shops.');
        $data = $request->validate([
            'name' => ['required', 'string', 'max:160'],
            'category' => ['nullable', 'string', 'max:100'],
            'categories' => ['nullable', 'array', 'min:1'],
            'categories.*' => ['required', 'string', 'max:100'],
            'address' => ['nullable', 'string', 'max:255'],
            'latitude' => ['nullable', 'numeric'],
            'longitude' => ['nullable', 'numeric'],
            'registration_payment_phone' => ['nullable', 'string', 'max:30'],
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
            'phone' => $request->input('registration_payment_phone') ?: $request->user()->phone,
            'payload' => ['shop_id' => $shop->id],
        ]);
        $shop->update(['registration_fee_payment_id' => $payment->id]);

        ProcessClickPesaPayment::queueUssdPush($payment);
        $shop->update(['registration_fee_status' => 'processing']);

        return response()->json([
            'message' => 'Shop saved. The ClickPesa registration fee request has been queued.',
            'shop' => $shop->fresh('registrationFeePayment'),
            'payment' => $payment->fresh(),
            'ussd_push' => ['status' => 'queued'],
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
        } catch (\Throwable $error) {
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
        $shop->update($data);

        return response()->json(['shop' => $shop->fresh('products')]);
    }

    public function product(Request $request, Shop $shop): JsonResponse
    {
        abort_unless($shop->seller_id === $request->user()->id, 403);
        abort_unless($shop->is_active, 422, 'Pay the shop registration fee before adding products.');
        $data = $request->validate([
            'name' => ['required', 'string', 'max:180'],
            'description' => ['nullable', 'string'],
            'price' => ['required', 'numeric', 'min:0'],
            'discount_price' => ['nullable', 'numeric', 'min:0'],
            'discount_percent' => ['nullable', 'numeric', 'min:0', 'max:100'],
            'delivery_price' => ['required', 'numeric', 'min:0'],
            'images' => ['required_without:product_images', 'array', 'min:3'],
            'images.*' => ['required', 'string', 'max:500'],
            'product_images' => ['nullable', 'array', 'min:3'],
            'product_images.*' => ['required', 'image', 'max:4096'],
            'stock' => ['required', 'integer', 'min:0'],
        ]);
        $uploadedImages = $this->storeProductImages($request->file('product_images', []));
        if ($uploadedImages !== []) {
            $data['images'] = $uploadedImages;
        }
        unset($data['product_images']);
        $effective = $data['discount_price'] ?? round($data['price'] * (1 - (($data['discount_percent'] ?? 0) / 100)), 2);
        $data['auto_total'] = $effective + $data['delivery_price'];
        $product = Product::create($data + ['shop_id' => $shop->id, 'seller_id' => $request->user()->id]);

        return response()->json(['product' => $product], 201);
    }

    public function updateProduct(Request $request, Product $product): JsonResponse
    {
        abort_unless($product->seller_id === $request->user()->id, 403);
        $data = $request->validate([
            'name' => ['required', 'string', 'max:180'],
            'description' => ['nullable', 'string'],
            'price' => ['required', 'numeric', 'min:0'],
            'discount_price' => ['nullable', 'numeric', 'min:0'],
            'discount_percent' => ['nullable', 'numeric', 'min:0', 'max:100'],
            'delivery_price' => ['required', 'numeric', 'min:0'],
            'images' => ['nullable', 'array', 'min:3'],
            'images.*' => ['required', 'string', 'max:500'],
            'product_images' => ['nullable', 'array', 'min:3'],
            'product_images.*' => ['required', 'image', 'max:4096'],
            'stock' => ['required', 'integer', 'min:0'],
        ]);
        $uploadedImages = $this->storeProductImages($request->file('product_images', []));
        if ($uploadedImages !== []) {
            $data['images'] = $uploadedImages;
        }
        $effective = $data['discount_price'] ?? round($data['price'] * (1 - (($data['discount_percent'] ?? 0) / 100)), 2);
        $data['auto_total'] = $effective + $data['delivery_price'];
        unset($data['product_images']);
        if (! array_key_exists('images', $data)) {
            unset($data['images']);
        }
        $product->update($data);

        return response()->json(['product' => $product->fresh('shop')]);
    }

    public function destroyProduct(Request $request, Product $product): JsonResponse
    {
        abort_unless($product->seller_id === $request->user()->id, 403);
        $product->update(['is_active' => false, 'stock' => 0]);

        return response()->json(['message' => 'Product removed.']);
    }

    /**
     * @param  array<int, UploadedFile>|UploadedFile|null  $files
     * @return array<int, string>
     */
    private function storeProductImages(array|UploadedFile|null $files): array
    {
        if ($files instanceof UploadedFile) {
            $files = [$files];
        }

        return collect($files ?? [])
            ->filter(fn ($file) => $file instanceof UploadedFile)
            ->map(fn (UploadedFile $file) => Storage::disk('public')->url($file->store('products', 'public')))
            ->values()
            ->all();
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
