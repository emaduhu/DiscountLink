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
        $query = Product::with('shop')->withAvg('ratings', 'rating')->withCount('ratings')->where('is_active', true)->where('stock', '>', 0);
        if ($search = $request->query('q')) {
            $query->where(fn ($builder) => $builder->where('name', 'like', "%{$search}%")->orWhere('description', 'like', "%{$search}%"));
        }
        if ($category = $request->query('category')) {
            $query->whereHas('shop', fn ($builder) => $builder->where('category', $category)->orWhereJsonContains('categories', $category));
        }
        return response()->json(['products' => $query->latest()->paginate(20)]);
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
                : $matches->count().' products ranked by visual similarity to the uploaded image.',
        ]);
    }

    public function rate(Request $request, Product $product): JsonResponse
    {
        abort_unless($request->user()->role === 'buyer', 403, 'Only buyers can rate products.');
        abort_unless($product->is_active, 422, 'This product is no longer available.');

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
}
