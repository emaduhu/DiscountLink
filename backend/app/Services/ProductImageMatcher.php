<?php

namespace App\Services;

use App\Models\Product;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Http;

class ProductImageMatcher
{
    private const MAX_MATCH_DISTANCE = 0.16;

    /**
     * @param  Collection<int, Product>  $products
     * @return Collection<int, Product>
     */
    public function match(string $queryImagePath, Collection $products, int $limit = 20): Collection
    {
        $query = $this->fingerprints($queryImagePath);
        if ($query === []) {
            return collect();
        }

        return $products
            ->map(function (Product $product) use ($query) {
                $score = $this->bestProductScore($query, $product);
                if ($score === null || $score > self::MAX_MATCH_DISTANCE) {
                    return null;
                }
                $product->setAttribute('image_match_score', round($score, 4));
                $product->setAttribute('image_match_percent', max(0, min(100, (int) round((1 - $score) * 100))));

                return $product;
            })
            ->filter()
            ->sortBy('image_match_score')
            ->take($limit)
            ->values();
    }

    /**
     * @param  array<int, array{histogram: array<int, float>, gray: array<int, float>, grid: array<int, float>, hash: array<int, int>}>  $query
     */
    private function bestProductScore(array $query, Product $product): ?float
    {
        $scores = collect($product->images ?? [])
            ->map(fn ($source) => $this->resolveImagePath((string) $source))
            ->filter()
            ->map(fn (string $path) => $this->fingerprints($path))
            ->filter(fn (array $fingerprints) => $fingerprints !== [])
            ->map(fn (array $candidate) => $this->distance($query, $candidate));

        return $scores->isEmpty() ? null : $scores->min();
    }

    private function resolveImagePath(string $source): ?string
    {
        $source = trim($source);
        if ($source === '') {
            return null;
        }

        if (is_file($source)) {
            return $source;
        }

        $publicUrl = rtrim(config('filesystems.disks.public.url'), '/');
        if (str_starts_with($source, $publicUrl.'/')) {
            $relative = substr($source, strlen($publicUrl) + 1);
            $path = storage_path('app/public/'.$relative);

            return is_file($path) ? $path : null;
        }

        if (str_starts_with($source, '/storage/')) {
            $path = storage_path('app/public/'.substr($source, 9));

            return is_file($path) ? $path : null;
        }

        if (str_starts_with($source, 'products/')) {
            $path = storage_path('app/public/'.$source);

            return is_file($path) ? $path : null;
        }

        $urlPath = parse_url($source, PHP_URL_PATH);
        if (is_string($urlPath) && str_starts_with($urlPath, '/storage/')) {
            $path = storage_path('app/public/'.ltrim(substr($urlPath, 9), '/'));

            return is_file($path) ? $path : null;
        }

        if (str_starts_with($source, 'http://') || str_starts_with($source, 'https://')) {
            try {
                $response = Http::timeout(5)->get($source);
                if (! $response->ok()) {
                    return null;
                }
                $path = tempnam(sys_get_temp_dir(), 'dl-product-image-');
                file_put_contents($path, $response->body());

                return $path;
            } catch (\Throwable) {
                return null;
            }
        }

        return null;
    }

    /**
     * @return array<int, array{histogram: array<int, float>, gray: array<int, float>, grid: array<int, float>, hash: array<int, int>}>
     */
    private function fingerprints(string $path): array
    {
        $content = @file_get_contents($path);
        if ($content === false) {
            return [];
        }

        $source = @imagecreatefromstring($content);
        if (! $source) {
            return [];
        }

        $width = imagesx($source);
        $height = imagesy($source);
        $short = min($width, $height);
        $crops = [
            [0, 0, $width, $height],
            [
                max(0, (int) (($width - $short) / 2)),
                max(0, (int) (($height - $short) / 2)),
                $short,
                $short,
            ],
            [
                (int) ($width * 0.1),
                (int) ($height * 0.1),
                max(1, (int) ($width * 0.8)),
                max(1, (int) ($height * 0.8)),
            ],
        ];

        $fingerprints = [];
        foreach ($crops as $crop) {
            $fingerprints[] = $this->fingerprintCrop($source, ...$crop);
        }
        imagedestroy($source);

        return array_values(array_filter($fingerprints));
    }

    /**
     * @return array{histogram: array<int, float>, gray: array<int, float>, grid: array<int, float>, hash: array<int, int>}|null
     */
    private function fingerprintCrop(\GdImage $source, int $srcX, int $srcY, int $srcW, int $srcH): ?array
    {
        $sample = imagecreatetruecolor(16, 16);
        imagecopyresampled(
            $sample,
            $source,
            0,
            0,
            $srcX,
            $srcY,
            16,
            16,
            $srcW,
            $srcH,
        );

        $histogram = array_fill(0, 64, 0.0);
        $gray = array_fill(0, 16, 0.0);
        $grid = [];
        for ($y = 0; $y < 16; $y++) {
            for ($x = 0; $x < 16; $x++) {
                $rgb = imagecolorat($sample, $x, $y);
                $r = ($rgb >> 16) & 0xff;
                $g = ($rgb >> 8) & 0xff;
                $b = $rgb & 0xff;
                if ($x % 2 === 0 && $y % 2 === 0) {
                    $grid[] = $r / 255;
                    $grid[] = $g / 255;
                    $grid[] = $b / 255;
                }
                $index = intdiv($r, 64) * 16 + intdiv($g, 64) * 4 + intdiv($b, 64);
                $histogram[$index]++;
                $gray[intdiv($this->grayFromRgb($r, $g, $b), 16)]++;
            }
        }
        imagedestroy($sample);

        $hashSample = imagecreatetruecolor(9, 8);
        imagecopyresampled(
            $hashSample,
            $source,
            0,
            0,
            $srcX,
            $srcY,
            9,
            8,
            $srcW,
            $srcH,
        );

        $hash = [];
        for ($y = 0; $y < 8; $y++) {
            for ($x = 0; $x < 8; $x++) {
                $hash[] = $this->grayAt($hashSample, $x, $y) > $this->grayAt($hashSample, $x + 1, $y) ? 1 : 0;
            }
        }
        imagedestroy($hashSample);

        return [
            'histogram' => array_map(fn (float $value) => $value / 256, $histogram),
            'gray' => array_map(fn (float $value) => $value / 256, $gray),
            'grid' => $grid,
            'hash' => $hash,
        ];
    }

    /**
     * @param  array<int, array{histogram: array<int, float>, gray: array<int, float>, grid: array<int, float>, hash: array<int, int>}>  $a
     * @param  array<int, array{histogram: array<int, float>, gray: array<int, float>, grid: array<int, float>, hash: array<int, int>}>  $b
     */
    private function distance(array $a, array $b): float
    {
        $best = 1.0;
        foreach ($a as $query) {
            foreach ($b as $candidate) {
                $best = min($best, $this->featureDistance($query, $candidate));
            }
        }

        return $best;
    }

    /**
     * @param  array{histogram: array<int, float>, gray: array<int, float>, grid: array<int, float>, hash: array<int, int>}  $a
     * @param  array{histogram: array<int, float>, gray: array<int, float>, grid: array<int, float>, hash: array<int, int>}  $b
     */
    private function featureDistance(array $a, array $b): float
    {
        $histogramDistance = 0.0;
        for ($i = 0; $i < 64; $i++) {
            $histogramDistance += abs($a['histogram'][$i] - $b['histogram'][$i]);
        }
        $histogramDistance = $histogramDistance / 2;

        $grayDistance = 0.0;
        for ($i = 0; $i < 16; $i++) {
            $grayDistance += abs($a['gray'][$i] - $b['gray'][$i]);
        }
        $grayDistance = $grayDistance / 2;

        $hashDistance = 0;
        for ($i = 0; $i < 64; $i++) {
            if ($a['hash'][$i] !== $b['hash'][$i]) {
                $hashDistance++;
            }
        }

        $gridDistance = 0.0;
        $gridCount = min(count($a['grid']), count($b['grid']));
        for ($i = 0; $i < $gridCount; $i++) {
            $gridDistance += abs($a['grid'][$i] - $b['grid'][$i]);
        }
        $gridDistance = $gridCount > 0 ? $gridDistance / $gridCount : 1.0;

        return ($histogramDistance * 0.2) + ($grayDistance * 0.1) + ($gridDistance * 0.35) + (($hashDistance / 64) * 0.35);
    }

    private function grayAt(\GdImage $image, int $x, int $y): int
    {
        $rgb = imagecolorat($image, $x, $y);
        $r = ($rgb >> 16) & 0xff;
        $g = ($rgb >> 8) & 0xff;
        $b = $rgb & 0xff;

        return $this->grayFromRgb($r, $g, $b);
    }

    private function grayFromRgb(int $r, int $g, int $b): int
    {
        return (int) round(($r * 0.299) + ($g * 0.587) + ($b * 0.114));
    }
}
