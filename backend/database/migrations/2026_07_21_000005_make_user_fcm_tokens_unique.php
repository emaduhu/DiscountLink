<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (DB::getDriverName() === 'mysql') {
            Schema::table('users', function (Blueprint $table): void {
                $table->string('fcm_token')->nullable()->collation('utf8mb4_bin')->change();
            });
        }

        DB::table('users')->where('fcm_token', '')->update(['fcm_token' => null]);

        do {
            $duplicates = DB::table('users')
                ->select('fcm_token')
                ->whereNotNull('fcm_token')
                ->groupBy('fcm_token')
                ->havingRaw('COUNT(*) > 1')
                ->orderBy('fcm_token')
                ->limit(100)
                ->pluck('fcm_token');

            foreach ($duplicates as $duplicate) {
                $ownerId = DB::table('users')
                    ->where('fcm_token', $duplicate)
                    ->orderByRaw('CASE WHEN deleted_at IS NULL THEN 0 ELSE 1 END')
                    ->orderByDesc('is_active')
                    ->orderByDesc('updated_at')
                    ->orderByDesc('id')
                    ->value('id');

                DB::table('users')
                    ->where('fcm_token', $duplicate)
                    ->where('id', '!=', $ownerId)
                    ->update(['fcm_token' => null]);
            }
        } while ($duplicates->isNotEmpty());

        Schema::table('users', function (Blueprint $table): void {
            $table->unique('fcm_token');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->dropUnique(['fcm_token']);
        });
    }
};
