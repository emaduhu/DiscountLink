<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Product;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ProductController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = Product::with('shop')->where('is_active', true)->where('stock', '>', 0);
        if ($search = $request->query('q')) {
            $query->where(fn ($builder) => $builder->where('name', 'like', "%{$search}%")->orWhere('description', 'like', "%{$search}%"));
        }
        if ($category = $request->query('category')) {
            $query->whereHas('shop', fn ($builder) => $builder->where('category', $category));
        }
        return response()->json(['products' => $query->latest()->paginate(20)]);
    }

    public function imageSearch(Request $request): JsonResponse
    {
        $data = $request->validate([
            'image' => ['required', 'image', 'max:4096'],
        ]);
        $label = pathinfo($request->file('image')->getClientOriginalName(), PATHINFO_FILENAME);
        $label = trim(preg_replace('/[^a-z0-9]+/i', ' ', $label) ?? '');
        abort_if($label === '', 422, 'The uploaded image name could not be used for search.');

        $products = Product::with('shop')
            ->where('is_active', true)
            ->where(fn ($query) => $query->where('name', 'like', '%'.$label.'%')->orWhere('description', 'like', '%'.$label.'%'))
            ->limit(20)
            ->get();
        return response()->json(['products' => $products, 'label' => $label, 'message' => 'Image uploads are matched by detected or filename label until a production vision provider is connected.']);
    }
}
