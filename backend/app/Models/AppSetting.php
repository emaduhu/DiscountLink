<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

#[Fillable(['key', 'value'])]
class AppSetting extends Model
{
    public static function get(string $key, ?string $default = null): ?string
    {
        return cache()->rememberForever("app_setting:{$key}", fn () => self::where('key', $key)->value('value') ?? $default);
    }

    public static function put(string $key, ?string $value): void
    {
        self::updateOrCreate(['key' => $key], ['value' => $value]);
        cache()->forget("app_setting:{$key}");
    }
}
