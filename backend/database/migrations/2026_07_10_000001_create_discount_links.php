<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('conversations', function (Blueprint $table) {
            $table->foreignId('product_id')->nullable()->after('order_id')->constrained()->nullOnDelete();
        });

        Schema::create('discount_links', function (Blueprint $table) {
            $table->id();
            $table->string('token', 64)->unique();
            $table->foreignId('conversation_id')->constrained()->cascadeOnDelete();
            $table->foreignId('product_id')->constrained()->cascadeOnDelete();
            $table->foreignId('seller_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('buyer_id')->constrained('users')->cascadeOnDelete();
            $table->decimal('discount_price', 14, 2);
            $table->timestamp('expires_at')->nullable();
            $table->timestamp('used_at')->nullable();
            $table->timestamps();
        });

        Schema::table('carts', function (Blueprint $table) {
            $table->foreignId('discount_link_id')->nullable()->after('product_id')->constrained('discount_links')->nullOnDelete();
            $table->decimal('unit_price_override', 14, 2)->nullable()->after('quantity');
        });
    }

    public function down(): void
    {
        Schema::table('carts', function (Blueprint $table) {
            $table->dropConstrainedForeignId('discount_link_id');
            $table->dropColumn('unit_price_override');
        });

        Schema::dropIfExists('discount_links');

        Schema::table('conversations', function (Blueprint $table) {
            $table->dropConstrainedForeignId('product_id');
        });
    }
};
