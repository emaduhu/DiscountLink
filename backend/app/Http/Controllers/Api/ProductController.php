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
        $data = $request->validate(['image_label' => ['required', 'string', 'max:120']]);
        $products = Product::with('shop')
            ->where('is_active', true)
            ->where(fn ($query) => $query->where('name', 'like', '%'.$data['image_label'].'%')->orWhere('description', 'like', '%'.$data['image_label'].'%'))
            ->limit(20)
            ->get();
        return response()->json(['products' => $products, 'message' => 'Image labels are accepted from the mobile ML layer or a production vision provider.']);
    }
}
