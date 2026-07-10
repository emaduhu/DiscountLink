<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('conversations', function (Blueprint $table) {
            $table->foreignId('blocked_by_id')->nullable()->after('user_two_id')->constrained('users')->nullOnDelete();
            $table->timestamp('blocked_at')->nullable()->after('blocked_by_id');
            $table->text('block_reason')->nullable()->after('blocked_at');
        });

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

    public function down(): void
    {
        Schema::dropIfExists('conversation_reports');

        Schema::table('conversations', function (Blueprint $table) {
            $table->dropConstrainedForeignId('blocked_by_id');
            $table->dropColumn(['blocked_at', 'block_reason']);
        });
    }
};
