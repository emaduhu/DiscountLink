<?php

namespace App\Models;

use Carbon\CarbonImmutable;
use DateTimeInterface;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Fillable(['seller_id', 'name', 'category', 'categories', 'address', 'latitude', 'longitude', 'opening_time', 'closing_time', 'timezone', 'is_active', 'registration_fee_amount', 'registration_fee_status', 'registration_fee_payment_id', 'registration_paid_at'])]
class Shop extends Model
{
    public const DEFAULT_TIMEZONE = 'Africa/Dar_es_Salaam';

    protected $appends = ['is_open', 'next_status_change_at'];

    protected function casts(): array
    {
        return [
            'categories' => 'array',
            'is_active' => 'boolean',
            'registration_fee_amount' => 'decimal:2',
            'registration_paid_at' => 'datetime',
        ];
    }

    public function seller(): BelongsTo
    {
        return $this->belongsTo(User::class, 'seller_id');
    }

    public function products(): HasMany
    {
        return $this->hasMany(Product::class);
    }

    public function registrationFeePayment(): BelongsTo
    {
        return $this->belongsTo(Payment::class, 'registration_fee_payment_id');
    }

    public function isOpenAt(DateTimeInterface|string|null $moment = null): bool
    {
        if (! $this->is_active) {
            return false;
        }

        [$opening, $closing] = $this->businessHoursInSeconds();
        if ($opening === null && $closing === null) {
            return true;
        }
        if ($opening === null || $closing === null) {
            return false;
        }
        if ($opening === $closing) {
            return true;
        }

        $now = $this->localMoment($moment);
        $current = ($now->hour * 3600) + ($now->minute * 60) + $now->second;

        return $opening < $closing
            ? $current >= $opening && $current < $closing
            : $current >= $opening || $current < $closing;
    }

    public function getIsOpenAttribute(): bool
    {
        return $this->isOpenAt();
    }

    public function getNextStatusChangeAtAttribute(): ?string
    {
        if (! $this->is_active) {
            return null;
        }

        [$opening, $closing] = $this->businessHoursInSeconds();
        if ($opening === null || $closing === null || $opening === $closing) {
            return null;
        }

        $now = $this->localMoment();
        $current = ($now->hour * 3600) + ($now->minute * 60) + $now->second;
        $startOfDay = $now->startOfDay();

        if ($opening < $closing) {
            $change = match (true) {
                $current < $opening => $startOfDay->addSeconds($opening),
                $current < $closing => $startOfDay->addSeconds($closing),
                default => $startOfDay->addDay()->addSeconds($opening),
            };
        } else {
            $change = match (true) {
                $current < $closing => $startOfDay->addSeconds($closing),
                $current < $opening => $startOfDay->addSeconds($opening),
                default => $startOfDay->addDay()->addSeconds($closing),
            };
        }

        return $change->toIso8601String();
    }

    public function getOpeningTimeAttribute(?string $value): ?string
    {
        return $this->shortTime($value);
    }

    public function getClosingTimeAttribute(?string $value): ?string
    {
        return $this->shortTime($value);
    }

    /**
     * @return array{0: int|null, 1: int|null}
     */
    private function businessHoursInSeconds(): array
    {
        return [
            $this->timeInSeconds($this->opening_time),
            $this->timeInSeconds($this->closing_time),
        ];
    }

    private function localMoment(DateTimeInterface|string|null $moment = null): CarbonImmutable
    {
        $timezone = in_array($this->timezone, timezone_identifiers_list(), true)
            ? $this->timezone
            : self::DEFAULT_TIMEZONE;

        return match (true) {
            $moment instanceof DateTimeInterface => CarbonImmutable::instance($moment)->setTimezone($timezone),
            is_string($moment) => CarbonImmutable::parse($moment, $timezone),
            default => CarbonImmutable::now($timezone),
        };
    }

    private function timeInSeconds(?string $time): ?int
    {
        if ($time === null || ! preg_match('/^(\d{2}):(\d{2})(?::(\d{2}))?$/', $time, $parts)) {
            return null;
        }

        return ((int) $parts[1] * 3600) + ((int) $parts[2] * 60) + (int) ($parts[3] ?? 0);
    }

    private function shortTime(?string $time): ?string
    {
        return $time === null ? null : substr($time, 0, 5);
    }
}
