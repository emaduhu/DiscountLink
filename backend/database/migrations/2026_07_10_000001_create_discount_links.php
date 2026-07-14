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
            DB::statement('ALTER TABLE conversations ADD COLUMN product_id INTEGER NULL');
            DB::statement('CREATE TABLE discount_links (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, token VARCHAR(64) NOT NULL, conversation_id INTEGER NOT NULL, product_id INTEGER NOT NULL, seller_id INTEGER NOT NULL, buyer_id INTEGER NOT NULL, discount_price NUMERIC NOT NULL, expires_at DATETIME NULL, used_at DATETIME NULL, created_at DATETIME NULL, updated_at DATETIME NULL)');
            DB::statement('CREATE UNIQUE INDEX discount_links_token_unique ON discount_links (token)');
            DB::statement('CREATE INDEX discount_links_conversation_id_index ON discount_links (conversation_id)');
            DB::statement('CREATE INDEX discount_links_product_id_index ON discount_links (product_id)');
            DB::statement('CREATE INDEX discount_links_seller_id_index ON discount_links (seller_id)');
            DB::statement('CREATE INDEX discount_links_buyer_id_index ON discount_links (buyer_id)');
            DB::statement('ALTER TABLE carts ADD COLUMN discount_link_id INTEGER NULL');
            DB::statement('ALTER TABLE carts ADD COLUMN unit_price_override NUMERIC NULL');
            DB::statement('CREATE INDEX carts_discount_link_id_index ON carts (discount_link_id)');
        } else {
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
