<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('delivery_assignments', function (Blueprint $table) {
            $table->decimal('deliverer_latitude', 10, 7)->nullable()->after('status');
            $table->decimal('deliverer_longitude', 10, 7)->nullable()->after('deliverer_latitude');
            $table->timestamp('location_updated_at')->nullable()->after('deliverer_longitude');
        });
    }

    public function down(): void
    {
        Schema::table('delivery_assignments', function (Blueprint $table) {
            $table->dropColumn([
                'deliverer_latitude',
                'deliverer_longitude',
                'location_updated_at',
            ]);
        });
    }
};
