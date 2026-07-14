<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::getConnection()->getDriverName() === 'sqlite') {
            if (! $this->hasColumn('orders', 'service_fee_rate')) {
                DB::statement('ALTER TABLE orders ADD COLUMN service_fee_rate NUMERIC NOT NULL DEFAULT 0');
            }
            if (! $this->hasColumn('orders', 'service_fee_total')) {
                DB::statement('ALTER TABLE orders ADD COLUMN service_fee_total NUMERIC NOT NULL DEFAULT 0');
            }
        } else {
            Schema::table('orders', function (Blueprint $table) {
                if (! $this->hasColumn('orders', 'service_fee_rate')) {
                    $table->decimal('service_fee_rate', 5, 2)->default(0)->after('delivery_total');
                }
                if (! $this->hasColumn('orders', 'service_fee_total')) {
                    $table->decimal('service_fee_total', 14, 2)->default(0)->after('service_fee_rate');
                }
            });
        }
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            if ($this->hasColumn('orders', 'service_fee_total')) {
                $table->dropColumn('service_fee_total');
            }
            if ($this->hasColumn('orders', 'service_fee_rate')) {
                $table->dropColumn('service_fee_rate');
            }
        });
    }

    private function hasColumn(string $table, string $column): bool
    {
        if (Schema::getConnection()->getDriverName() !== 'sqlite') {
            return Schema::hasColumn($table, $column);
        }

        return collect(DB::select("PRAGMA table_info({$table})"))
            ->contains(fn (object $row): bool => $row->name === $column);
    }
};
