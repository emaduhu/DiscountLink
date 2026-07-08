<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\Shop;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ShopController extends Controller
{
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
        ]);
        $categories = collect($data['categories'] ?? [$data['category'] ?? null])
            ->filter()
            ->map(fn (string $category) => trim($category))
            ->filter()
            ->unique()
            ->values();
        abort_if($categories->isEmpty(), 422, 'Choose at least one shop category.');
        $data['address'] = $data['address'] ?: $request->user()->address;
        $data['category'] = $categories->first();
        $data['categories'] = $categories->all();
        $shop = Shop::create($data + ['seller_id' => $request->user()->id]);
        return response()->json(['shop' => $shop], 201);
    }

    public function mine(Request $request): JsonResponse
    {
        return response()->json(['shops' => $request->user()->shops()->with('products')->latest()->get()]);
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
        $data['category'] = $categories->first();
        $data['categories'] = $categories->all();
        $shop->update($data);
        return response()->json(['shop' => $shop->fresh('products')]);
    }

    public function product(Request $request, Shop $shop): JsonResponse
    {
        abort_unless($shop->seller_id === $request->user()->id, 403);
        $data = $request->validate([
            'name' => ['required', 'string', 'max:180'],
            'description' => ['nullable', 'string'],
            'price' => ['required', 'numeric', 'min:0'],
            'discount_price' => ['nullable', 'numeric', 'min:0'],
            'discount_percent' => ['nullable', 'numeric', 'min:0', 'max:100'],
            'delivery_price' => ['required', 'numeric', 'min:0'],
            'images' => ['required', 'array', 'min:3'],
            'images.*' => ['required', 'string', 'max:500'],
            'stock' => ['required', 'integer', 'min:0'],
        ]);
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
            'stock' => ['required', 'integer', 'min:0'],
        ]);
        $effective = $data['discount_price'] ?? round($data['price'] * (1 - (($data['discount_percent'] ?? 0) / 100)), 2);
        $data['auto_total'] = $effective + $data['delivery_price'];
        if (! array_key_exists('images', $data)) {
            unset($data['images']);
        }
        $product->update($data);
        return response()->json(['product' => $product->fresh('shop')]);
    }
}
