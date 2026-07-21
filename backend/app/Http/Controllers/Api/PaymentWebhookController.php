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
        $payload = $request->all();
        abort_unless($clickPesa->hasValidWebhookChecksum($payload), 403, 'Invalid ClickPesa webhook checksum.');

        $clickPesa->applyCallback($payload);

        return response()->json(['received' => true]);
    }
}
