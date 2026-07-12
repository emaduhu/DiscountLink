<?php

namespace App\Services;

use App\Models\Product;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Http;

class ProductImageMatcher
{
    private const STRONG_MATCH_DISTANCE = 0.16;
    private const MAX_MATCH_DISTANCE = 0.17;

    /**
     * @var array<string, array<int, array{
     *     histogram: array<int, float>,
     *     gray: array<int, float>,
     *     grid: array<int, float>,
     *     luminance: array<int, float>,
     *     edge: array<int, float>,
     *     hash: array<int, int>,
     *     average_hash: array<int, int>
     * }>>
     */
    private array $fingerprintCache = [];

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
                $match = $this->bestProductMatch($query, $product);
                if ($match === null || $match['score'] > self::MAX_MATCH_DISTANCE) {
                    return null;
                }
                $score = $match['score'];
                $product->setAttribute('image_match_score', round($score, 4));
                $product->setAttribute('image_match_percent', max(0, min(100, (int) round((1 - ($score / self::STRONG_MATCH_DISTANCE)) * 100))));
                $product->setAttribute('image_match_source', $match['source']);
                $product->setAttribute('image_match_compared_images', $match['compared_images']);

                return $product;
            })
            ->filter()
            ->sortBy('image_match_score')
            ->take($limit)
            ->values();
    }

    /**
     * @param  array<int, array{histogram: array<int, float>, gray: array<int, float>, grid: array<int, float>, luminance: array<int, float>, edge: array<int, float>, hash: array<int, int>, average_hash: array<int, int>}>  $query
     * @return array{score: float, source: string, compared_images: int}|null
     */
    private function bestProductMatch(array $query, Product $product): ?array
    {
        $best = null;
        $comparedImages = 0;

        foreach (($product->images ?? []) as $source) {
            $source = (string) $source;
            $path = $this->resolveImagePath($source);
            if (! $path) {
                continue;
            }

            $candidate = $this->fingerprints($path);
            if ($candidate === []) {
                continue;
            }

            $comparedImages++;
            $score = $this->distance($query, $candidate);
            if ($best === null || $score < $best['score']) {
                $best = [
                    'score' => $score,
                    'source' => $source,
                    'compared_images' => $comparedImages,
                ];
            }
        }

        if ($best !== null) {
            $best['compared_images'] = $comparedImages;
        }

        return $best;
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
     * @return array<int, array{histogram: array<int, float>, gray: array<int, float>, grid: array<int, float>, luminance: array<int, float>, edge: array<int, float>, hash: array<int, int>, average_hash: array<int, int>}>
     */
    private function fingerprints(string $path): array
    {
        if (array_key_exists($path, $this->fingerprintCache)) {
            return $this->fingerprintCache[$path];
        }

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
            [
                (int) ($width * 0.15),
                (int) ($height * 0.15),
                max(1, (int) ($width * 0.7)),
                max(1, (int) ($height * 0.7)),
            ],
        ];

        $fingerprints = [];
        foreach ($crops as $crop) {
            $fingerprints[] = $this->fingerprintCrop($source, ...$crop);
        }
        imagedestroy($source);

        return $this->fingerprintCache[$path] = array_values(array_filter($fingerprints));
    }

    /**
     * @return array{histogram: array<int, float>, gray: array<int, float>, grid: array<int, float>, luminance: array<int, float>, edge: array<int, float>, hash: array<int, int>, average_hash: array<int, int>}|null
     */
    private function fingerprintCrop(\GdImage $source, int $srcX, int $srcY, int $srcW, int $srcH): ?array
    {
        $sample = $this->makeCanvas(32, 32);
        imagecopyresampled(
            $sample,
            $source,
            0,
            0,
            $srcX,
            $srcY,
            32,
            32,
            $srcW,
            $srcH,
        );

        $histogram = array_fill(0, 64, 0.0);
        $gray = array_fill(0, 16, 0.0);
        $gridTotals = array_fill(0, 64 * 3, 0.0);
        $luminanceTotals = array_fill(0, 64, 0.0);
        $grayPixels = [];

        for ($y = 0; $y < 32; $y++) {
            for ($x = 0; $x < 32; $x++) {
                $rgb = imagecolorat($sample, $x, $y);
                $r = ($rgb >> 16) & 0xFF;
                $g = ($rgb >> 8) & 0xFF;
                $b = $rgb & 0xFF;
                $pixelGray = $this->grayFromRgb($r, $g, $b);
                $cell = intdiv($y, 4) * 8 + intdiv($x, 4);
                $gridIndex = $cell * 3;
                $gridTotals[$gridIndex] += $r / 255;
                $gridTotals[$gridIndex + 1] += $g / 255;
                $gridTotals[$gridIndex + 2] += $b / 255;
                $luminanceTotals[$cell] += $pixelGray / 255;
                $grayPixels[$y][$x] = $pixelGray;
                $index = intdiv($r, 64) * 16 + intdiv($g, 64) * 4 + intdiv($b, 64);
                $histogram[$index]++;
                $gray[intdiv($pixelGray, 16)]++;
            }
        }
        imagedestroy($sample);

        $edgeTotals = array_fill(0, 64, 0.0);
        $edgeMax = 0.0;
        for ($y = 1; $y < 31; $y++) {
            for ($x = 1; $x < 31; $x++) {
                $gx = (-$grayPixels[$y - 1][$x - 1]) + $grayPixels[$y - 1][$x + 1]
                    + (-2 * $grayPixels[$y][$x - 1]) + (2 * $grayPixels[$y][$x + 1])
                    + (-$grayPixels[$y + 1][$x - 1]) + $grayPixels[$y + 1][$x + 1];
                $gy = $grayPixels[$y - 1][$x - 1] + (2 * $grayPixels[$y - 1][$x]) + $grayPixels[$y - 1][$x + 1]
                    - $grayPixels[$y + 1][$x - 1] - (2 * $grayPixels[$y + 1][$x]) - $grayPixels[$y + 1][$x + 1];
                $magnitude = min(1.0, sqrt(($gx * $gx) + ($gy * $gy)) / 1020);
                $cell = intdiv($y, 4) * 8 + intdiv($x, 4);
                $edgeTotals[$cell] += $magnitude;
                $edgeMax = max($edgeMax, $edgeTotals[$cell]);
            }
        }

        $hashSample = $this->makeCanvas(9, 8);
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

        $averageHashSample = $this->makeCanvas(8, 8);
        imagecopyresampled(
            $averageHashSample,
            $source,
            0,
            0,
            $srcX,
            $srcY,
            8,
            8,
            $srcW,
            $srcH,
        );

        $averageHashValues = [];
        $averageHashMean = 0.0;
        for ($y = 0; $y < 8; $y++) {
            for ($x = 0; $x < 8; $x++) {
                $value = $this->grayAt($averageHashSample, $x, $y);
                $averageHashValues[] = $value;
                $averageHashMean += $value;
            }
        }
        imagedestroy($averageHashSample);
        $averageHashMean /= 64;

        return [
            'histogram' => array_map(fn (float $value) => $value / 1024, $histogram),
            'gray' => array_map(fn (float $value) => $value / 1024, $gray),
            'grid' => array_map(fn (float $value) => $value / 16, $gridTotals),
            'luminance' => array_map(fn (float $value) => $value / 16, $luminanceTotals),
            'edge' => $edgeMax > 0 ? array_map(fn (float $value) => $value / $edgeMax, $edgeTotals) : $edgeTotals,
            'hash' => $hash,
            'average_hash' => array_map(fn (int $value) => $value >= $averageHashMean ? 1 : 0, $averageHashValues),
        ];
    }

    /**
     * @param  array<int, array{histogram: array<int, float>, gray: array<int, float>, grid: array<int, float>, luminance: array<int, float>, edge: array<int, float>, hash: array<int, int>, average_hash: array<int, int>}>  $a
     * @param  array<int, array{histogram: array<int, float>, gray: array<int, float>, grid: array<int, float>, luminance: array<int, float>, edge: array<int, float>, hash: array<int, int>, average_hash: array<int, int>}>  $b
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
     * @param  array{histogram: array<int, float>, gray: array<int, float>, grid: array<int, float>, luminance: array<int, float>, edge: array<int, float>, hash: array<int, int>, average_hash: array<int, int>}  $a
     * @param  array{histogram: array<int, float>, gray: array<int, float>, grid: array<int, float>, luminance: array<int, float>, edge: array<int, float>, hash: array<int, int>, average_hash: array<int, int>}  $b
     */
    private function featureDistance(array $a, array $b): float
    {
        $histogramDistance = $this->normalizedL1Distance($a['histogram'], $b['histogram']);
        $grayDistance = $this->normalizedL1Distance($a['gray'], $b['gray']);
        $gridDistance = $this->meanAbsoluteDistance($a['grid'], $b['grid']);
        $luminanceDistance = $this->meanAbsoluteDistance($a['luminance'], $b['luminance']);
        $edgeDistance = $this->meanAbsoluteDistance($a['edge'], $b['edge']);

        $hashDistance = 0;
        for ($i = 0; $i < 64; $i++) {
            if ($a['hash'][$i] !== $b['hash'][$i]) {
                $hashDistance++;
            }
        }

        $averageHashDistance = 0;
        for ($i = 0; $i < 64; $i++) {
            if ($a['average_hash'][$i] !== $b['average_hash'][$i]) {
                $averageHashDistance++;
            }
        }

        return ($histogramDistance * 0.25)
            + ($grayDistance * 0.06)
            + ($gridDistance * 0.27)
            + ($luminanceDistance * 0.09)
            + ($edgeDistance * 0.12)
            + (($hashDistance / 64) * 0.13)
            + (($averageHashDistance / 64) * 0.08);
    }

    private function makeCanvas(int $width, int $height): \GdImage
    {
        $image = imagecreatetruecolor($width, $height);
        imagealphablending($image, true);
        imagesavealpha($image, false);
        $white = imagecolorallocate($image, 255, 255, 255);
        imagefilledrectangle($image, 0, 0, $width - 1, $height - 1, $white);

        return $image;
    }

    /**
     * @param  array<int, float>  $a
     * @param  array<int, float>  $b
     */
    private function normalizedL1Distance(array $a, array $b): float
    {
        $distance = 0.0;
        $count = min(count($a), count($b));
        for ($i = 0; $i < $count; $i++) {
            $distance += abs($a[$i] - $b[$i]);
        }

        return $distance / 2;
    }

    /**
     * @param  array<int, float>  $a
     * @param  array<int, float>  $b
     */
    private function meanAbsoluteDistance(array $a, array $b): float
    {
        $distance = 0.0;
        $count = min(count($a), count($b));
        for ($i = 0; $i < $count; $i++) {
            $distance += abs($a[$i] - $b[$i]);
        }

        return $count > 0 ? $distance / $count : 1.0;
    }

    private function grayAt(\GdImage $image, int $x, int $y): int
    {
        $rgb = imagecolorat($image, $x, $y);
        $r = ($rgb >> 16) & 0xFF;
        $g = ($rgb >> 8) & 0xFF;
        $b = $rgb & 0xFF;

        return $this->grayFromRgb($r, $g, $b);
    }

    private function grayFromRgb(int $r, int $g, int $b): int
    {
        return (int) round(($r * 0.299) + ($g * 0.587) + ($b * 0.114));
    }
}
