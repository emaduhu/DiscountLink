<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProductMediaResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'type' => $this->type,
            'url' => $this->publicUrl(),
            'position' => $this->sort_order,
            'mime_type' => $this->mime_type,
            'size_bytes' => $this->size_bytes,
        ];
    }
}
