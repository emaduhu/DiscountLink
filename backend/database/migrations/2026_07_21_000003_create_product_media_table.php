<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('product_media', function (Blueprint $table) {
            $table->id();
            $table->foreignId('product_id')->constrained()->cascadeOnDelete();
            $table->string('type', 16);
            $table->string('disk', 32)->nullable();
            $table->string('path', 2048);
            $table->string('mime_type', 100)->nullable();
            $table->unsignedBigInteger('size_bytes')->nullable();
            $table->unsignedInteger('width')->nullable();
            $table->unsignedInteger('height')->nullable();
            $table->unsignedBigInteger('duration_ms')->nullable();
            $table->unsignedTinyInteger('sort_order');
            $table->timestamps();

            $table->unique(['product_id', 'sort_order']);
            $table->index(['product_id', 'type']);
        });

        $this->backfillLegacyImages();
    }

    public function down(): void
    {
        Schema::dropIfExists('product_media');
    }

    private function backfillLegacyImages(): void
    {
        DB::table('products')
            ->select(['id', 'images'])
            ->whereNotNull('images')
            ->orderBy('id')
            ->chunkById(200, function ($products): void {
                $now = now();
                $rows = [];

                foreach ($products as $product) {
                    $images = is_array($product->images)
                        ? $product->images
                        : json_decode((string) $product->images, true);

                    foreach (array_slice(is_array($images) ? $images : [], 0, 3) as $position => $url) {
                        if (! is_string($url) || trim($url) === '') {
                            continue;
                        }

                        [$disk, $path] = $this->storageLocation(trim($url));
                        $rows[] = [
                            'product_id' => $product->id,
                            'type' => 'image',
                            'disk' => $disk,
                            'path' => $path,
                            'mime_type' => $this->imageMimeType($path),
                            'size_bytes' => null,
                            'width' => null,
                            'height' => null,
                            'duration_ms' => null,
                            'sort_order' => $position,
                            'created_at' => $now,
                            'updated_at' => $now,
                        ];
                    }
                }

                if ($rows !== []) {
                    DB::table('product_media')->insert($rows);
                }
            }, 'id');
    }

    /**
     * @return array{0: string|null, 1: string}
     */
    private function storageLocation(string $url): array
    {
        $path = parse_url($url, PHP_URL_PATH);
        $appHost = parse_url((string) config('app.url'), PHP_URL_HOST);
        $urlHost = parse_url($url, PHP_URL_HOST);
        $isLocalUrl = $urlHost === null || $urlHost === false || $urlHost === $appHost;

        if ($isLocalUrl && is_string($path) && str_contains($path, '/storage/')) {
            return ['public', ltrim(substr($path, strpos($path, '/storage/') + strlen('/storage/')), '/')];
        }

        if ($isLocalUrl && str_starts_with($url, 'products/')) {
            return ['public', $url];
        }

        return [null, $url];
    }

    private function imageMimeType(string $path): ?string
    {
        return match (strtolower(pathinfo(parse_url($path, PHP_URL_PATH) ?: $path, PATHINFO_EXTENSION))) {
            'jpg', 'jpeg' => 'image/jpeg',
            'png' => 'image/png',
            'webp' => 'image/webp',
            default => null,
        };
    }
};
