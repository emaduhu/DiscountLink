<?php

namespace Tests\Feature;

use App\Models\ApiToken;
use App\Models\Product;
use App\Models\ProductMedia;
use App\Models\Shop;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class ProductMediaTest extends TestCase
{
    use RefreshDatabase;

    private User $seller;

    private Shop $shop;

    private string $token = 'product-media-test-token';

    protected function setUp(): void
    {
        parent::setUp();

        Storage::fake('public');
        $this->seller = User::factory()->create(['role' => 'seller']);
        ApiToken::create([
            'user_id' => $this->seller->id,
            'name' => 'test',
            'token_hash' => hash('sha256', $this->token),
        ]);
        $this->shop = Shop::create([
            'seller_id' => $this->seller->id,
            'name' => 'Media Shop',
            'category' => 'Electronics',
            'address' => 'Dar es Salaam',
            'is_active' => true,
        ]);
    }

    public function test_seller_can_create_replace_clear_and_delete_ordered_product_media(): void
    {
        $response = $this->withToken($this->token)->post("/api/shops/{$this->shop->id}/products", $this->payload([
            'product_images' => $this->images('original'),
            'product_videos' => $this->videos('original', 2),
        ]), ['Accept' => 'application/json']);

        $response->assertCreated()
            ->assertJsonCount(3, 'product.images')
            ->assertJsonCount(5, 'product.media')
            ->assertJsonPath('product.media.0.type', 'image')
            ->assertJsonPath('product.media.0.position', 0)
            ->assertJsonPath('product.media.3.type', 'video')
            ->assertJsonPath('product.media.3.position', 3)
            ->assertJsonStructure([
                'product' => ['media' => [['id', 'type', 'url', 'position', 'mime_type', 'size_bytes']]],
            ]);

        $product = Product::findOrFail($response->json('product.id'));
        $originalPaths = $product->media->pluck('path')->all();
        foreach ($originalPaths as $path) {
            Storage::disk('public')->assertExists($path);
        }

        $response = $this->withToken($this->token)->post("/api/products/{$product->id}", $this->payload([
            'product_images' => $this->images('replacement'),
            'product_videos' => $this->videos('replacement', 1),
        ]), ['Accept' => 'application/json']);

        $response->assertOk()
            ->assertJsonCount(3, 'product.images')
            ->assertJsonCount(4, 'product.media')
            ->assertJsonPath('product.media.3.type', 'video');
        foreach ($originalPaths as $path) {
            Storage::disk('public')->assertMissing($path);
        }

        $videoPath = $product->fresh()->media()->where('type', 'video')->value('path');
        $this->withToken($this->token)->postJson("/api/products/{$product->id}", $this->payload([
            'clear_videos' => true,
        ]))->assertOk()->assertJsonCount(3, 'product.media');
        Storage::disk('public')->assertMissing($videoPath);

        $remainingPaths = $product->fresh()->media->pluck('path')->all();
        $this->withToken($this->token)
            ->deleteJson("/api/products/{$product->id}")
            ->assertOk()
            ->assertJsonPath('message', 'Product removed.');

        $this->assertDatabaseMissing('product_media', ['product_id' => $product->id]);
        $this->assertSame([], $product->fresh()->images);
        foreach ($remainingPaths as $path) {
            Storage::disk('public')->assertMissing($path);
        }
    }

    public function test_product_media_limits_are_validated(): void
    {
        $this->withToken($this->token)->post("/api/shops/{$this->shop->id}/products", $this->payload([
            'product_images' => $this->images('too-many', 4),
            'product_videos' => $this->videos('too-many', 3),
        ]), ['Accept' => 'application/json'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['product_images', 'product_videos']);

        $this->assertSame(0, ProductMedia::count());
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function payload(array $overrides = []): array
    {
        return $overrides + [
            'name' => 'Camera',
            'description' => 'A test product',
            'price' => 100000,
            'discount_price' => 90000,
            'delivery_price' => 5000,
            'stock' => 4,
        ];
    }

    /**
     * @return array<int, UploadedFile>
     */
    private function images(string $prefix, int $count = 3): array
    {
        $baseSize = 100 + (abs(crc32($prefix)) % 40);

        return collect(range(1, $count))
            ->map(fn (int $position) => UploadedFile::fake()->image(
                "{$prefix}-{$position}.jpg",
                $baseSize + $position,
                $baseSize + $position,
            ))
            ->all();
    }

    /**
     * @return array<int, UploadedFile>
     */
    private function videos(string $prefix, int $count): array
    {
        return collect(range(1, $count))
            ->map(fn (int $position) => UploadedFile::fake()->createWithContent(
                "{$prefix}-{$position}.mp4",
                "\x00\x00\x00\x18ftypisom{$prefix}-{$position}",
            )->mimeType('video/mp4'))
            ->all();
    }
}
