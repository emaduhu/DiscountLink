<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->text('delivery_code_encrypted')->nullable()->after('delivery_code_demo');
        });

        DB::table('orders')
            ->whereNotNull('delivery_code_demo')
            ->select(['id', 'delivery_code_demo'])
            ->orderBy('id')
            ->chunkById(200, function ($orders): void {
                foreach ($orders as $order) {
                    DB::table('orders')->where('id', $order->id)->update([
                        'delivery_code_encrypted' => Crypt::encryptString((string) $order->delivery_code_demo),
                        'delivery_code_demo' => null,
                    ]);
                }
            });
    }

    public function down(): void
    {
        DB::table('orders')
            ->whereNotNull('delivery_code_encrypted')
            ->select(['id', 'delivery_code_encrypted'])
            ->orderBy('id')
            ->chunkById(200, function ($orders): void {
                foreach ($orders as $order) {
                    DB::table('orders')->where('id', $order->id)->update([
                        'delivery_code_demo' => Crypt::decryptString((string) $order->delivery_code_encrypted),
                    ]);
                }
            });

        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn('delivery_code_encrypted');
        });
    }
};
