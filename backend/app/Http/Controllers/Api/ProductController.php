<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\ProductRating;
use App\Services\ProductImageMatcher;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ProductController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = Product::with('shop')
            ->withAvg('ratings', 'rating')
            ->withCount('ratings')
            ->where('is_active', true)
            ->where('stock', '>', 0)
            ->whereHas('shop', fn ($shopQuery) => $shopQuery->where('is_active', true));

        if ($search = trim((string) $request->query('q'))) {
            $query->where(fn ($builder) => $builder
                ->where('name', 'like', "%{$search}%")
                ->orWhere('description', 'like', "%{$search}%")
                ->orWhereHas('shop', fn ($shopQuery) => $shopQuery
                    ->where('name', 'like', "%{$search}%")
                    ->orWhere('category', 'like', "%{$search}%")));
        }

        if ($category = $request->query('category')) {
            $query->whereHas('shop', fn ($builder) => $builder->where('category', $category)->orWhereJsonContains('categories', $category));
        }

        return response()->json(['products' => $query->latest()->paginate($this->perPage($request))]);
    }

    public function show(Request $request, Product $product): JsonResponse
    {
        $product->load('shop')->loadAvg('ratings', 'rating')->loadCount('ratings');

        abort_unless(
            $product->is_active && $product->stock > 0 && $product->shop?->is_active,
            404,
            'This product is no longer available.',
        );

        return response()->json(['product' => $product]);
    }

    public function imageSearch(Request $request, ProductImageMatcher $matcher): JsonResponse
    {
        $request->validate([
            'image' => ['required', 'image', 'mimes:jpg,jpeg,png,webp', 'max:8192'],
        ], [
            'image.required' => 'Upload a product image to match.',
            'image.image' => 'The uploaded file must be an image.',
            'image.mimes' => 'Use a JPG, PNG, or WebP image.',
            'image.max' => 'Use an image smaller than 8 MB.',
        ]);

        $image = $request->file('image');

        $products = Product::with('shop')
            ->withAvg('ratings', 'rating')
            ->withCount('ratings')
            ->where('is_active', true)
            ->where('stock', '>', 0)
            ->whereHas('shop', fn ($shopQuery) => $shopQuery->where('is_active', true))
            ->get();

        $matches = $matcher->match($image->getRealPath(), $products);

        return response()->json([
            'products' => $matches,
            'matches_count' => $matches->count(),
            'uploaded_image' => [
                'name' => $image->getClientOriginalName(),
                'mime' => $image->getMimeType(),
                'size' => $image->getSize(),
            ],
            'message' => $matches->isEmpty()
                ? 'No visually similar products were found.'
                : $matches->count().' close visual match(es) found for the uploaded image.',
        ]);
    }

    public function rate(Request $request, Product $product): JsonResponse
    {
        abort_unless(in_array($request->user()->role, ['buyer', 'seller'], true), 403, 'Only buyers and sellers can rate products.');
        abort_unless(
            $product->is_active && $product->stock > 0 && $product->shop?->is_active,
            422,
            'This product is no longer available.',
        );

        $data = $request->validate([
            'rating' => ['required', 'integer', 'min:1', 'max:5'],
            'comment' => ['nullable', 'string', 'max:1000'],
        ]);

        ProductRating::updateOrCreate(
            ['product_id' => $product->id, 'buyer_id' => $request->user()->id],
            $data,
        );

        return response()->json([
            'product' => $product->fresh('shop')->loadAvg('ratings', 'rating')->loadCount('ratings'),
        ]);
    }

    private function perPage(Request $request, int $default = 20, int $max = 50): int
    {
        return min($max, max(1, (int) $request->query('per_page', $default)));
    }
}
