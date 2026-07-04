<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\ClickPesaService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PaymentWebhookController extends Controller
{
    public function clickpesa(Request $request, ClickPesaService $clickPesa): JsonResponse
    {
        $clickPesa->applyCallback($request->all());
        return response()->json(['received' => true]);
    }
}
