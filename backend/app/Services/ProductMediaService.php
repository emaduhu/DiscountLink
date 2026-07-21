<?php

namespace App\Services;

use App\Models\Product;
use App\Models\ProductMedia;
use GdImage;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use InvalidArgumentException;
use RuntimeException;
use Symfony\Component\Process\ExecutableFinder;
use Symfony\Component\Process\Process;
use Throwable;

class ProductMediaService
{
    public const IMAGE_COUNT = 3;

    public const VIDEO_LIMIT = 2;

    private const DISK = 'public';

    private const MAX_IMAGE_DIMENSION = 1920;

    /**
     * Update a product and replace only the supplied media groups.
     *
     * A null media argument leaves that group unchanged. Supplying an empty
     * video array removes every video. Images must always contain exactly
     * IMAGE_COUNT items when replaced.
     *
     * @param  array<string, mixed>  $attributes
     * @param  array<int, UploadedFile>|null  $imageFiles
     * @param  array<int, string>|null  $imageUrls
     * @param  array<int, UploadedFile>|null  $videoFiles
     */
    public function synchronize(
        Product $product,
        array $attributes,
        ?array $imageFiles = null,
        ?array $imageUrls = null,
        ?array $videoFiles = null,
    ): Product {
        if ($imageFiles !== null && $imageUrls !== null) {
            throw new InvalidArgumentException('Supply uploaded images or image URLs, not both.');
        }

        if (($imageFiles !== null && count($imageFiles) !== self::IMAGE_COUNT)
            || ($imageUrls !== null && count($imageUrls) !== self::IMAGE_COUNT)) {
            throw new InvalidArgumentException('A product must have exactly three images.');
        }

        if ($videoFiles !== null && count($videoFiles) > self::VIDEO_LIMIT) {
            throw new InvalidArgumentException('A product can have at most two videos.');
        }

        $newRows = [];
        $newlyCreatedFiles = [];
        $replacingImages = $imageFiles !== null || $imageUrls !== null;
        $replacingVideos = $videoFiles !== null;
        $committed = false;

        try {
            if ($imageFiles !== null) {
                foreach (array_values($imageFiles) as $position => $file) {
                    $row = $this->storeImage($product, $file, $position);
                    $newRows[] = $row['attributes'];
                    if ($row['created']) {
                        $newlyCreatedFiles[] = $row['attributes'];
                    }
                }
            } elseif ($imageUrls !== null) {
                foreach (array_values($imageUrls) as $position => $url) {
                    $newRows[] = $this->externalImage(trim($url), $position);
                }
            }

            if ($videoFiles !== null) {
                foreach (array_values($videoFiles) as $videoPosition => $file) {
                    $row = $this->storeVideo($product, $file, self::IMAGE_COUNT + $videoPosition);
                    $newRows[] = $row['attributes'];
                    if ($row['created']) {
                        $newlyCreatedFiles[] = $row['attributes'];
                    }
                }
            }

            $oldFiles = DB::transaction(function () use (
                $product,
                $attributes,
                $newRows,
                $replacingImages,
                $replacingVideos,
            ): array {
                $types = array_values(array_filter([
                    $replacingImages ? 'image' : null,
                    $replacingVideos ? 'video' : null,
                ]));
                $oldMedia = $types === []
                    ? collect()
                    : $product->media()->whereIn('type', $types)->get();

                if ($types !== []) {
                    $product->media()->whereIn('type', $types)->delete();
                }

                foreach ($newRows as $row) {
                    $product->media()->create($row);
                }

                if ($replacingImages) {
                    $attributes['images'] = collect($newRows)
                        ->where('type', 'image')
                        ->map(fn (array $row): string => $this->publicUrl($row))
                        ->values()
                        ->all();
                }

                if ($attributes !== []) {
                    $product->update($attributes);
                }

                return $oldMedia
                    ->filter(fn (ProductMedia $media) => $media->disk && $this->isManagedPath($media->path))
                    ->map(fn (ProductMedia $media): array => ['disk' => $media->disk, 'path' => $media->path])
                    ->values()
                    ->all();
            });
            $committed = true;

            $newPaths = collect($newRows)
                ->filter(fn (array $row) => isset($row['disk']) && $row['disk'] && $this->isManagedPath($row['path']))
                ->map(fn (array $row): string => $row['disk'].'|'.$row['path'])
                ->all();

            $this->deleteUnreferencedFiles(array_values(array_filter(
                $oldFiles,
                fn (array $old): bool => ! in_array($old['disk'].'|'.$old['path'], $newPaths, true),
            )));

            return $product->fresh(['shop', 'media']);
        } catch (Throwable $error) {
            if (! $committed) {
                $this->deleteFiles($newlyCreatedFiles);
            }

            throw $error;
        }
    }

    /**
     * Deactivate a product and remove every locally managed media file.
     */
    public function deactivate(Product $product): void
    {
        $oldFiles = $product->media()
            ->get()
            ->filter(fn (ProductMedia $media) => $media->disk && $this->isManagedPath($media->path))
            ->map(fn (ProductMedia $media): array => ['disk' => $media->disk, 'path' => $media->path])
            ->values()
            ->all();

        DB::transaction(function () use ($product): void {
            $product->media()->delete();
            $product->update([
                'images' => [],
                'is_active' => false,
                'stock' => 0,
            ]);
        });

        $this->deleteUnreferencedFiles($oldFiles);
    }

    /**
     * @return array{attributes: array<string, mixed>, created: bool}
     */
    private function storeImage(Product $product, UploadedFile $file, int $position): array
    {
        $sourcePath = $file->getRealPath();
        if (! is_string($sourcePath) || $sourcePath === '') {
            throw new RuntimeException('The uploaded image could not be read.');
        }

        $hash = hash_file('sha256', $sourcePath);
        if (! is_string($hash)) {
            throw new RuntimeException('The uploaded image could not be hashed.');
        }

        $imageInfo = @getimagesize($sourcePath);
        if (! is_array($imageInfo)) {
            throw new RuntimeException('The uploaded image is invalid.');
        }

        [$width, $height] = $imageInfo;
        $mimeType = $imageInfo['mime'] ?? $file->getMimeType() ?? 'application/octet-stream';
        $optimized = $this->optimizeImage($file, $mimeType);
        $extension = $optimized === null ? $this->imageExtension($mimeType) : 'webp';
        $path = sprintf(
            'products/%d/images/%02d-%s.%s',
            $product->id,
            $position,
            substr($hash, 0, 24),
            $extension,
        );
        $disk = Storage::disk(self::DISK);
        $created = ! $disk->exists($path);

        try {
            if ($created) {
                if ($optimized !== null) {
                    if (! $disk->put($path, $optimized['contents'], ['visibility' => 'public'])) {
                        throw new RuntimeException('The optimized product image could not be stored.');
                    }
                    $width = $optimized['width'];
                    $height = $optimized['height'];
                    $mimeType = 'image/webp';
                } else {
                    $stored = $disk->putFileAs(dirname($path), $file, basename($path), ['visibility' => 'public']);
                    if ($stored === false) {
                        throw new RuntimeException('The product image could not be stored.');
                    }
                }
            } elseif ($optimized !== null) {
                $width = $optimized['width'];
                $height = $optimized['height'];
                $mimeType = 'image/webp';
            }

            return [
                'attributes' => [
                    'type' => 'image',
                    'disk' => self::DISK,
                    'path' => $path,
                    'mime_type' => $mimeType,
                    'size_bytes' => $disk->size($path),
                    'width' => $width,
                    'height' => $height,
                    'duration_ms' => null,
                    'sort_order' => $position,
                ],
                'created' => $created,
            ];
        } catch (Throwable $error) {
            if ($created) {
                $disk->delete($path);
            }

            throw $error;
        }
    }

    /**
     * @return array{attributes: array<string, mixed>, created: bool}
     */
    private function storeVideo(Product $product, UploadedFile $file, int $position): array
    {
        $sourcePath = $file->getRealPath();
        if (! is_string($sourcePath) || $sourcePath === '') {
            throw new RuntimeException('The uploaded video could not be read.');
        }

        $hash = hash_file('sha256', $sourcePath);
        if (! is_string($hash)) {
            throw new RuntimeException('The uploaded video could not be hashed.');
        }

        $mimeType = $file->getMimeType() ?? 'application/octet-stream';
        $metadata = $this->probeVideo($sourcePath);
        $path = sprintf(
            'products/%d/videos/%02d-%s.%s',
            $product->id,
            $position,
            substr($hash, 0, 24),
            $this->videoExtension($mimeType),
        );
        $disk = Storage::disk(self::DISK);
        $created = ! $disk->exists($path);

        try {
            if ($created) {
                $stored = $disk->putFileAs(dirname($path), $file, basename($path), ['visibility' => 'public']);
                if ($stored === false) {
                    throw new RuntimeException('The product video could not be stored.');
                }
            }

            return [
                'attributes' => [
                    'type' => 'video',
                    'disk' => self::DISK,
                    'path' => $path,
                    'mime_type' => $mimeType,
                    'size_bytes' => $disk->size($path),
                    'width' => $metadata['width'],
                    'height' => $metadata['height'],
                    'duration_ms' => $metadata['duration_ms'],
                    'sort_order' => $position,
                ],
                'created' => $created,
            ];
        } catch (Throwable $error) {
            if ($created) {
                $disk->delete($path);
            }

            throw $error;
        }
    }

    /**
     * @return array<string, mixed>
     */
    private function externalImage(string $url, int $position): array
    {
        [$disk, $path] = $this->storageLocation($url);
        $mimeType = match (strtolower(pathinfo(parse_url($url, PHP_URL_PATH) ?: $url, PATHINFO_EXTENSION))) {
            'jpg', 'jpeg' => 'image/jpeg',
            'png' => 'image/png',
            'webp' => 'image/webp',
            default => null,
        };

        return [
            'type' => 'image',
            'disk' => $disk,
            'path' => $path,
            'mime_type' => $mimeType,
            'size_bytes' => $disk && Storage::disk($disk)->exists($path) ? Storage::disk($disk)->size($path) : null,
            'width' => null,
            'height' => null,
            'duration_ms' => null,
            'sort_order' => $position,
        ];
    }

    /**
     * @return array{contents: string, width: int, height: int}|null
     */
    private function optimizeImage(UploadedFile $file, string $mimeType): ?array
    {
        if (! function_exists('imagecreatefromstring') || ! function_exists('imagewebp')) {
            return null;
        }

        $sourceBytes = @file_get_contents($file->getRealPath());
        if (! is_string($sourceBytes)) {
            return null;
        }

        $source = @imagecreatefromstring($sourceBytes);
        if (! $source instanceof GdImage) {
            return null;
        }

        try {
            if ($mimeType === 'image/jpeg') {
                $source = $this->orientJpeg($source, $file->getRealPath());
            }

            $sourceWidth = imagesx($source);
            $sourceHeight = imagesy($source);
            $scale = min(1, self::MAX_IMAGE_DIMENSION / max($sourceWidth, $sourceHeight));
            $targetWidth = max(1, (int) round($sourceWidth * $scale));
            $targetHeight = max(1, (int) round($sourceHeight * $scale));
            $target = imagecreatetruecolor($targetWidth, $targetHeight);
            if (! $target instanceof GdImage) {
                return null;
            }

            imagealphablending($target, false);
            imagesavealpha($target, true);
            $transparent = imagecolorallocatealpha($target, 0, 0, 0, 127);
            imagefill($target, 0, 0, $transparent);

            if (! imagecopyresampled(
                $target,
                $source,
                0,
                0,
                0,
                0,
                $targetWidth,
                $targetHeight,
                $sourceWidth,
                $sourceHeight,
            )) {
                imagedestroy($target);

                return null;
            }

            ob_start();
            $encoded = imagewebp($target, null, 82);
            $contents = ob_get_clean();
            imagedestroy($target);

            if (! $encoded || ! is_string($contents) || $contents === '') {
                return null;
            }

            if ($scale === 1 && strlen($contents) >= strlen($sourceBytes)) {
                return null;
            }

            return [
                'contents' => $contents,
                'width' => $targetWidth,
                'height' => $targetHeight,
            ];
        } finally {
            imagedestroy($source);
        }
    }

    private function orientJpeg(GdImage $image, string $path): GdImage
    {
        if (! function_exists('exif_read_data')) {
            return $image;
        }

        $orientation = (int) (@exif_read_data($path)['Orientation'] ?? 1);
        if (in_array($orientation, [2, 4, 5, 7], true)) {
            imageflip($image, in_array($orientation, [2, 5], true) ? IMG_FLIP_HORIZONTAL : IMG_FLIP_VERTICAL);
        }

        $degrees = match ($orientation) {
            3 => 180,
            5, 6 => -90,
            7, 8 => 90,
            default => 0,
        };
        if ($degrees === 0) {
            return $image;
        }

        $rotated = imagerotate($image, $degrees, 0);
        if (! $rotated instanceof GdImage) {
            return $image;
        }

        imagedestroy($image);

        return $rotated;
    }

    private function imageExtension(string $mimeType): string
    {
        return match ($mimeType) {
            'image/jpeg' => 'jpg',
            'image/png' => 'png',
            'image/webp' => 'webp',
            default => throw new InvalidArgumentException('Unsupported image type.'),
        };
    }

    private function videoExtension(string $mimeType): string
    {
        return match ($mimeType) {
            'video/mp4' => 'mp4',
            'video/quicktime' => 'mov',
            'video/webm' => 'webm',
            default => throw new InvalidArgumentException('Unsupported video type.'),
        };
    }

    /**
     * Use ffprobe when the host provides it; uploads remain supported without it.
     *
     * @return array{width: int|null, height: int|null, duration_ms: int|null}
     */
    private function probeVideo(string $path): array
    {
        $empty = ['width' => null, 'height' => null, 'duration_ms' => null];
        $ffprobe = (new ExecutableFinder)->find('ffprobe');
        if (! $ffprobe) {
            return $empty;
        }

        try {
            $process = new Process([
                $ffprobe,
                '-v', 'error',
                '-select_streams', 'v:0',
                '-show_entries', 'stream=width,height,duration:format=duration',
                '-of', 'json',
                $path,
            ]);
            $process->setTimeout(5)->run();
            if (! $process->isSuccessful()) {
                return $empty;
            }

            $probe = json_decode($process->getOutput(), true);
            $stream = is_array($probe['streams'][0] ?? null) ? $probe['streams'][0] : [];
            $duration = $stream['duration'] ?? ($probe['format']['duration'] ?? null);

            return [
                'width' => isset($stream['width']) ? (int) $stream['width'] : null,
                'height' => isset($stream['height']) ? (int) $stream['height'] : null,
                'duration_ms' => is_numeric($duration) ? (int) round(((float) $duration) * 1000) : null,
            ];
        } catch (Throwable $error) {
            Log::debug('Video metadata could not be read.', ['error' => $error->getMessage()]);

            return $empty;
        }
    }

    /**
     * @param  array<string, mixed>  $row
     */
    private function publicUrl(array $row): string
    {
        return $row['disk']
            ? Storage::disk($row['disk'])->url($row['path'])
            : $row['path'];
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

    private function isManagedPath(string $path): bool
    {
        return str_starts_with($path, 'products/');
    }

    /**
     * @param  array<int, array{disk: string, path: string}>  $files
     */
    private function deleteUnreferencedFiles(array $files): void
    {
        try {
            $this->deleteFiles(array_values(array_filter($files, function (array $file): bool {
                return ! ProductMedia::query()
                    ->where('disk', $file['disk'])
                    ->where('path', $file['path'])
                    ->exists();
            })));
        } catch (Throwable $error) {
            Log::warning('Product media cleanup could not be completed.', ['error' => $error->getMessage()]);
        }
    }

    /**
     * @param  array<int, array<string, mixed>>  $files
     */
    private function deleteFiles(array $files): void
    {
        foreach (collect($files)->unique(fn (array $file) => $file['disk'].'|'.$file['path']) as $file) {
            if (! isset($file['disk'], $file['path']) || ! $file['disk'] || ! $this->isManagedPath($file['path'])) {
                continue;
            }

            try {
                Storage::disk($file['disk'])->delete($file['path']);
            } catch (Throwable $error) {
                Log::warning('A product media file could not be deleted.', [
                    'disk' => $file['disk'],
                    'path' => $file['path'],
                    'error' => $error->getMessage(),
                ]);
            }
        }
    }
}
