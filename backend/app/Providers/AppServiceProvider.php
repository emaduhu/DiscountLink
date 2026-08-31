<?php

namespace App\Providers;

use App\Services\AuditLogger;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        foreach (['created', 'updated', 'deleted', 'restored', 'forceDeleted'] as $event) {
            Event::listen("eloquent.{$event}: *", function (string $eventName, array $data) use ($event): void {
                $model = $data[0] ?? null;

                if ($model instanceof Model) {
                    app(AuditLogger::class)->recordModelEvent($event, $model);
                }
            });
        }
    }
}
