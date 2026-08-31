<?php

namespace App\Http\Middleware;

use App\Services\AuditLogger;
use Closure;
use Illuminate\Contracts\Auth\Authenticatable;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Symfony\Component\HttpFoundation\Response;
use Throwable;

class AuditHttpActions
{
    public function __construct(private readonly AuditLogger $audit)
    {
    }

    public function handle(Request $request, Closure $next): Response
    {
        $startedAt = microtime(true);
        $actorBeforeAction = $this->actor($request);

        try {
            $response = $next($request);
        } catch (Throwable $error) {
            $this->audit->recordHttpAction(
                $request,
                null,
                (microtime(true) - $startedAt) * 1000,
                $error,
                $actorBeforeAction,
            );

            throw $error;
        }

        $this->audit->recordHttpAction(
            $request,
            $response,
            (microtime(true) - $startedAt) * 1000,
            null,
            $actorBeforeAction,
        );

        return $response;
    }

    private function actor(Request $request): ?Authenticatable
    {
        return $request->user() ?: Auth::user();
    }
}
