<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('shops', function (Blueprint $table) {
            if (! Schema::hasColumn('shops', 'categories')) {
                $table->json('categories')->nullable()->after('category');
            }
        });

        DB::table('shops')
            ->whereNull('categories')
            ->orderBy('id')
            ->chunkById(100, function ($shops): void {
                foreach ($shops as $shop) {
                    DB::table('shops')
                        ->where('id', $shop->id)
                        ->update(['categories' => json_encode(array_values(array_filter([$shop->category])))]);
                }
            });

        Schema::table('orders', function (Blueprint $table) {
            if (! Schema::hasColumn('orders', 'delivery_code_demo')) {
                $table->string('delivery_code_demo', 12)->nullable()->after('delivery_code_hash');
            }
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            if (Schema::hasColumn('orders', 'delivery_code_demo')) {
                $table->dropColumn('delivery_code_demo');
            }
        });

        Schema::table('shops', function (Blueprint $table) {
            if (Schema::hasColumn('shops', 'categories')) {
                $table->dropColumn('categories');
            }
        });
    }
};
