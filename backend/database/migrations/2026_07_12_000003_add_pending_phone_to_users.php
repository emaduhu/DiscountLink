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
            if (! $this->hasColumn('users', 'pending_phone')) {
                DB::statement('ALTER TABLE users ADD COLUMN pending_phone VARCHAR NULL');
                DB::statement('CREATE UNIQUE INDEX users_pending_phone_unique ON users (pending_phone)');
            }
        } else {
            Schema::table('users', function (Blueprint $table) {
                if (! $this->hasColumn('users', 'pending_phone')) {
                    $table->string('pending_phone')->nullable()->unique()->after('phone');
                }
            });
        }
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            if ($this->hasColumn('users', 'pending_phone')) {
                $table->dropUnique(['pending_phone']);
                $table->dropColumn('pending_phone');
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
