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
            if (! $this->hasColumn('users', 'is_available')) {
                DB::statement('ALTER TABLE users ADD COLUMN is_available INTEGER NOT NULL DEFAULT 1');
                DB::statement('CREATE INDEX users_is_available_index ON users (is_available)');
            }
        } else {
            Schema::table('users', function (Blueprint $table) {
                if (! $this->hasColumn('users', 'is_available')) {
                    $table->boolean('is_available')->default(true)->after('is_active')->index();
                }
            });
        }
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            if ($this->hasColumn('users', 'is_available')) {
                $table->dropColumn('is_available');
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
