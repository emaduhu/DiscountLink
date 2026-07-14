<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if ($this->hasColumn('users', 'username')) {
            Schema::table('users', function (Blueprint $table) {
                $table->dropColumn('username');
            });
        }
    }

    public function down(): void
    {
        if (! $this->hasColumn('users', 'username')) {
            Schema::table('users', function (Blueprint $table) {
                $table->string('username')->nullable()->unique()->after('name');
            });
        }
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
