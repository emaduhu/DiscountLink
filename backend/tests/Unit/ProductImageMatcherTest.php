<?php

namespace Tests\Unit;

use App\Models\Product;
use App\Services\ProductImageMatcher;
use Illuminate\Support\Collection;
use Tests\TestCase;

class ProductImageMatcherTest extends TestCase
{
    public function test_it_returns_close_visual_matches_only(): void
    {
        $queryPath = $this->makeImage([240, 40, 40], [255, 230, 210]);
        $closePath = $this->makeImage([238, 42, 42], [255, 232, 212]);
        $differentPath = $this->makeImage([35, 80, 220], [220, 245, 255]);

        $products = new Collection([
            new Product(['name' => 'Similar red product', 'images' => [$closePath]]),
            new Product(['name' => 'Different blue product', 'images' => [$differentPath]]),
        ]);

        $matches = app(ProductImageMatcher::class)->match($queryPath, $products);

        $this->assertCount(1, $matches);
        $this->assertSame('Similar red product', $matches->first()->name);
        $this->assertGreaterThanOrEqual(76, $matches->first()->image_match_percent);
    }

    public function test_it_returns_empty_results_for_unrelated_images(): void
    {
        $queryPath = $this->makeImage([245, 40, 40], [255, 235, 220]);
        $differentPath = $this->makeImage([30, 90, 230], [220, 245, 255]);

        $products = new Collection([
            new Product(['name' => 'Different product', 'images' => [$differentPath]]),
        ]);

        $matches = app(ProductImageMatcher::class)->match($queryPath, $products);

        $this->assertCount(0, $matches);
    }

    public function test_it_matches_products_despite_padding_and_lighting_changes(): void
    {
        $queryPath = $this->makeImage([240, 40, 40], [255, 230, 210]);
        $paddedPath = $this->makePaddedImage($queryPath);
        $brighterPath = $this->makeImage([255, 60, 60], [255, 245, 230]);
        $differentPath = $this->makeImage([35, 80, 220], [220, 245, 255]);

        $products = new Collection([
            new Product(['name' => 'Padded same product', 'images' => [$paddedPath]]),
            new Product(['name' => 'Brighter same product', 'images' => [$brighterPath]]),
            new Product(['name' => 'Different blue product', 'images' => [$differentPath]]),
        ]);

        $matches = app(ProductImageMatcher::class)->match($queryPath, $products);

        $this->assertSame([
            'Padded same product',
            'Brighter same product',
        ], $matches->pluck('name')->all());
        $this->assertGreaterThan($matches[0]->image_match_score, $matches[1]->image_match_score);
    }

    /**
     * @param  array{0:int,1:int,2:int}  $primary
     * @param  array{0:int,1:int,2:int}  $secondary
     */
    private function makeImage(array $primary, array $secondary): string
    {
        $path = tempnam(sys_get_temp_dir(), 'dl-image-match-test-').'.png';
        $image = imagecreatetruecolor(140, 140);
        $background = imagecolorallocate($image, $secondary[0], $secondary[1], $secondary[2]);
        $foreground = imagecolorallocate($image, $primary[0], $primary[1], $primary[2]);
        imagefilledrectangle($image, 0, 0, 139, 139, $background);
        imagefilledellipse($image, 70, 70, 88, 88, $foreground);
        imagefilledrectangle($image, 45, 42, 95, 98, $foreground);
        imagepng($image, $path);
        imagedestroy($image);

        $this->beforeApplicationDestroyed(fn () => @unlink($path));

        return $path;
    }

    private function makePaddedImage(string $sourcePath): string
    {
        $path = tempnam(sys_get_temp_dir(), 'dl-image-match-test-').'.png';
        $image = imagecreatetruecolor(180, 180);
        $source = imagecreatefrompng($sourcePath);
        $background = imagecolorallocate($image, 255, 255, 255);
        imagefilledrectangle($image, 0, 0, 179, 179, $background);
        imagecopyresampled($image, $source, 20, 20, 0, 0, 140, 140, 140, 140);
        imagepng($image, $path);
        imagedestroy($source);
        imagedestroy($image);

        $this->beforeApplicationDestroyed(fn () => @unlink($path));

        return $path;
    }
}
