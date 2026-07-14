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
            DB::statement('ALTER TABLE conversations ADD COLUMN blocked_by_id INTEGER NULL');
            DB::statement('ALTER TABLE conversations ADD COLUMN blocked_at DATETIME NULL');
            DB::statement('ALTER TABLE conversations ADD COLUMN block_reason TEXT NULL');
        } else {
            Schema::table('conversations', function (Blueprint $table) {
                $table->foreignId('blocked_by_id')->nullable()->after('user_two_id')->constrained('users')->nullOnDelete();
                $table->timestamp('blocked_at')->nullable()->after('blocked_by_id');
                $table->text('block_reason')->nullable()->after('blocked_at');
            });
        }

        if (Schema::getConnection()->getDriverName() === 'sqlite') {
            Schema::create('conversation_reports', function (Blueprint $table) {
                $table->id();
                $table->unsignedBigInteger('conversation_id')->index();
                $table->unsignedBigInteger('reporter_id')->index();
                $table->unsignedBigInteger('reported_user_id')->nullable()->index();
                $table->string('reason');
                $table->text('details')->nullable();
                $table->string('status')->default('open')->index();
                $table->timestamp('reviewed_at')->nullable();
                $table->timestamps();
            });
        } else {
            Schema::create('conversation_reports', function (Blueprint $table) {
                $table->id();
                $table->foreignId('conversation_id')->constrained()->cascadeOnDelete();
                $table->foreignId('reporter_id')->constrained('users')->cascadeOnDelete();
                $table->foreignId('reported_user_id')->nullable()->constrained('users')->nullOnDelete();
                $table->string('reason');
                $table->text('details')->nullable();
                $table->string('status')->default('open')->index();
                $table->timestamp('reviewed_at')->nullable();
                $table->timestamps();
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('conversation_reports');

        Schema::table('conversations', function (Blueprint $table) {
            $table->dropConstrainedForeignId('blocked_by_id');
            $table->dropColumn(['blocked_at', 'block_reason']);
        });
    }
};
