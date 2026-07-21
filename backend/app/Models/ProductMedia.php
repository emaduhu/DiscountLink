<?php

namespace App\Models;

use App\Http\Resources\ProductMediaResource;
use Illuminate\Database\Eloquent\Attributes\Appends;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Attributes\UseResource;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Facades\Storage;

#[Fillable([
    'product_id', 'type', 'disk', 'path', 'mime_type', 'size_bytes', 'width', 'height', 'duration_ms', 'sort_order',
])]
#[Hidden(['product_id', 'disk', 'path', 'width', 'height', 'duration_ms', 'sort_order', 'created_at', 'updated_at'])]
#[Appends(['url', 'position'])]
#[UseResource(ProductMediaResource::class)]
class ProductMedia extends Model
{
    protected $table = 'product_media';

    protected function casts(): array
    {
        return [
            'size_bytes' => 'integer',
            'width' => 'integer',
            'height' => 'integer',
            'duration_ms' => 'integer',
            'sort_order' => 'integer',
        ];
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }

    public function publicUrl(): string
    {
        return $this->disk
            ? Storage::disk($this->disk)->url($this->path)
            : $this->path;
    }

    public function getUrlAttribute(): string
    {
        return $this->publicUrl();
    }

    public function getPositionAttribute(): int
    {
        return $this->sort_order;
    }
}
