<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('shops', function (Blueprint $table) {
            $table->time('opening_time')->nullable()->after('longitude');
            $table->time('closing_time')->nullable()->after('opening_time');
            $table->string('timezone', 64)->default('Africa/Dar_es_Salaam')->after('closing_time');
        });
    }

    public function down(): void
    {
        Schema::table('shops', function (Blueprint $table) {
            $table->dropColumn(['opening_time', 'closing_time', 'timezone']);
        });
    }
};
