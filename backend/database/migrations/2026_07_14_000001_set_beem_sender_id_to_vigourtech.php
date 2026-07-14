<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::table('app_settings')->updateOrInsert(
            ['key' => 'beem_sender_id'],
            ['value' => 'VIGOURTECH', 'updated_at' => now(), 'created_at' => now()],
        );
        cache()->forget('app_setting:beem_sender_id');
    }

    public function down(): void
    {
        DB::table('app_settings')->where('key', 'beem_sender_id')->delete();
        cache()->forget('app_setting:beem_sender_id');
    }
};
