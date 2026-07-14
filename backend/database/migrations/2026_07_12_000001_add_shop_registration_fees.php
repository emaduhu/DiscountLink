<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('payments', function (Blueprint $table) {
            if (! $this->hasColumn('payments', 'shop_id')) {
                $table->foreignId('shop_id')->nullable()->after('order_id')->constrained()->nullOnDelete();
            }
        });

        Schema::table('shops', function (Blueprint $table) {
            if (! $this->hasColumn('shops', 'registration_fee_amount')) {
                $table->decimal('registration_fee_amount', 14, 2)->default(0)->after('is_active');
            }
            if (! $this->hasColumn('shops', 'registration_fee_status')) {
                $table->string('registration_fee_status')->default('waived')->after('registration_fee_amount')->index();
            }
            if (! $this->hasColumn('shops', 'registration_fee_payment_id')) {
                $table->foreignId('registration_fee_payment_id')->nullable()->after('registration_fee_status')->constrained('payments')->nullOnDelete();
            }
            if (! $this->hasColumn('shops', 'registration_paid_at')) {
                $table->timestamp('registration_paid_at')->nullable()->after('registration_fee_payment_id');
            }
        });
    }

    public function down(): void
    {
        Schema::table('shops', function (Blueprint $table) {
            if ($this->hasColumn('shops', 'registration_fee_payment_id')) {
                $table->dropConstrainedForeignId('registration_fee_payment_id');
            }
            if ($this->hasColumn('shops', 'registration_paid_at')) {
                $table->dropColumn('registration_paid_at');
            }
            if ($this->hasColumn('shops', 'registration_fee_status')) {
                $table->dropColumn('registration_fee_status');
            }
            if ($this->hasColumn('shops', 'registration_fee_amount')) {
                $table->dropColumn('registration_fee_amount');
            }
        });

        Schema::table('payments', function (Blueprint $table) {
            if ($this->hasColumn('payments', 'shop_id')) {
                $table->dropConstrainedForeignId('shop_id');
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
