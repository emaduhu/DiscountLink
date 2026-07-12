<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            if (! Schema::hasColumn('orders', 'service_fee_rate')) {
                $table->decimal('service_fee_rate', 5, 2)->default(0)->after('delivery_total');
            }
            if (! Schema::hasColumn('orders', 'service_fee_total')) {
                $table->decimal('service_fee_total', 14, 2)->default(0)->after('service_fee_rate');
            }
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            if (Schema::hasColumn('orders', 'service_fee_total')) {
                $table->dropColumn('service_fee_total');
            }
            if (Schema::hasColumn('orders', 'service_fee_rate')) {
                $table->dropColumn('service_fee_rate');
            }
        });
    }
};
