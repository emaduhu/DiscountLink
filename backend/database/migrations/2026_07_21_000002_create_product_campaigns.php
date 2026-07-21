<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('product_campaigns', function (Blueprint $table) {
            $table->id();
            $table->string('reference')->unique();
            $table->foreignId('seller_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('product_id')->constrained()->restrictOnDelete();
            $table->foreignId('payment_id')->nullable()->unique()->constrained('payments')->nullOnDelete();
            $table->string('channel', 16)->index();
            $table->string('status', 32)->default('pending_payment')->index();
            $table->string('title', 120);
            $table->text('message');
            $table->decimal('unit_price', 14, 4);
            $table->unsignedInteger('recipient_count')->default(0);
            $table->decimal('total_cost', 14, 2)->default(0);
            $table->unsignedInteger('sent_count')->default(0);
            $table->unsignedInteger('failed_count')->default(0);
            $table->timestamp('paid_at')->nullable();
            $table->timestamp('started_at')->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->timestamps();

            $table->index(['seller_id', 'created_at']);
            $table->index(['status', 'paid_at']);
        });

        Schema::create('product_campaign_deliveries', function (Blueprint $table) {
            $table->id();
            $table->foreignId('product_campaign_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->text('destination');
            $table->string('status', 24)->default('pending')->index();
            $table->string('provider_reference')->nullable()->index();
            $table->unsignedTinyInteger('attempt_count')->default(0);
            $table->text('last_error')->nullable();
            $table->timestamp('sent_at')->nullable();
            $table->timestamps();

            $table->unique(['product_campaign_id', 'user_id']);
            $table->index(['product_campaign_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('product_campaign_deliveries');
        Schema::dropIfExists('product_campaigns');
    }
};
