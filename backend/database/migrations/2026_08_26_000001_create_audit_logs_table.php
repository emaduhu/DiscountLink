<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('audit_logs', function (Blueprint $table) {
            $table->id();
            $table->string('request_id', 64)->nullable()->index();
            $table->string('source', 32)->default('system')->index();
            $table->string('event', 80)->index();
            $table->string('action', 160)->nullable()->index();
            $table->string('actor_type', 160)->nullable();
            $table->unsignedBigInteger('actor_id')->nullable()->index();
            $table->string('actor_role', 40)->nullable()->index();
            $table->string('actor_name', 160)->nullable();
            $table->string('actor_email', 190)->nullable();
            $table->string('auditable_type', 160)->nullable();
            $table->unsignedBigInteger('auditable_id')->nullable();
            $table->string('method', 10)->nullable();
            $table->string('route_name', 160)->nullable()->index();
            $table->string('path', 512)->nullable();
            $table->text('url')->nullable();
            $table->string('ip_address', 45)->nullable();
            $table->text('user_agent')->nullable();
            $table->unsignedSmallInteger('response_status')->nullable()->index();
            $table->unsignedInteger('duration_ms')->nullable();
            $table->json('metadata')->nullable();
            $table->json('old_values')->nullable();
            $table->json('new_values')->nullable();
            $table->timestamp('created_at')->useCurrent()->index();

            $table->index(['auditable_type', 'auditable_id']);
            $table->index(['actor_type', 'actor_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('audit_logs');
    }
};
