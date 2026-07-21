<?php

namespace Tests\Unit;

use App\Models\Shop;
use Carbon\CarbonImmutable;
use PHPUnit\Framework\TestCase;

class ShopBusinessHoursTest extends TestCase
{
    protected function tearDown(): void
    {
        CarbonImmutable::setTestNow();

        parent::tearDown();
    }

    public function test_shop_is_open_inside_a_same_day_window_and_closed_at_its_boundary(): void
    {
        $shop = new Shop([
            'is_active' => true,
            'opening_time' => '09:00',
            'closing_time' => '17:00',
            'timezone' => 'Africa/Dar_es_Salaam',
        ]);

        $this->assertFalse($shop->isOpenAt('2026-07-21 08:59:59'));
        $this->assertTrue($shop->isOpenAt('2026-07-21 09:00:00'));
        $this->assertTrue($shop->isOpenAt('2026-07-21 16:59:59'));
        $this->assertFalse($shop->isOpenAt('2026-07-21 17:00:00'));
    }

    public function test_overnight_hours_span_midnight(): void
    {
        $shop = new Shop([
            'is_active' => true,
            'opening_time' => '20:00',
            'closing_time' => '04:00',
            'timezone' => 'Africa/Dar_es_Salaam',
        ]);

        $this->assertTrue($shop->isOpenAt('2026-07-21 23:30:00'));
        $this->assertTrue($shop->isOpenAt('2026-07-22 03:59:59'));
        $this->assertFalse($shop->isOpenAt('2026-07-22 04:00:00'));
        $this->assertFalse($shop->isOpenAt('2026-07-22 12:00:00'));
    }

    public function test_existing_active_shop_without_hours_remains_open(): void
    {
        $shop = new Shop(['is_active' => true]);

        $this->assertTrue($shop->isOpenAt('2026-07-21 12:00:00'));
        $this->assertNull($shop->next_status_change_at);
    }

    public function test_next_status_change_is_exposed_in_the_shop_timezone(): void
    {
        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-07-21 10:00:00', 'Africa/Dar_es_Salaam'));
        $shop = new Shop([
            'is_active' => true,
            'opening_time' => '09:00',
            'closing_time' => '17:00',
            'timezone' => 'Africa/Dar_es_Salaam',
        ]);

        $this->assertTrue($shop->is_open);
        $this->assertSame('2026-07-21T17:00:00+03:00', $shop->next_status_change_at);
        $this->assertSame('09:00', $shop->opening_time);
        $this->assertSame('17:00', $shop->closing_time);
    }
}
