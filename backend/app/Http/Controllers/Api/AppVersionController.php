<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AppSetting;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AppVersionController extends Controller
{
    public function __invoke(Request $request): JsonResponse
    {
        $platform = $request->query('platform', 'android');

        return response()->json([
            'platform' => $platform,
            'latest_version' => AppSetting::get("app_latest_version_{$platform}", AppSetting::get('app_latest_version', '1.0.0')),
            'minimum_version' => AppSetting::get("app_minimum_version_{$platform}", AppSetting::get('app_minimum_version', '1.0.0')),
            'latest_build' => (int) AppSetting::get("app_latest_build_{$platform}", AppSetting::get('app_latest_build', '1')),
            'minimum_build' => (int) AppSetting::get("app_minimum_build_{$platform}", AppSetting::get('app_minimum_build', '1')),
            'update_url' => AppSetting::get("app_update_url_{$platform}", AppSetting::get('app_update_url', '')),
            'message' => AppSetting::get('app_update_message', 'A new DiscountLink update is available.'),
        ]);
    }
}
