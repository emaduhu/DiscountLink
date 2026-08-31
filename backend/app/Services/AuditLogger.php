<?php

namespace App\Services;

use App\Models\ApiToken;
use App\Models\AppSetting;
use App\Models\AuditLog;
use DateTimeInterface;
use Illuminate\Contracts\Auth\Authenticatable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;
use Throwable;
use UnitEnum;

class AuditLogger
{
    private const REDACTED = '[redacted]';

    private const SENSITIVE_KEYS = [
        'access_key',
        'access_token',
        'api_key',
        'authorization',
        'bearer',
        'checksum',
        'client_secret',
        'code',
        'code_hash',
        'cookie',
        'credential',
        'delivery_code_demo',
        'delivery_code_encrypted',
        'delivery_code_hash',
        'fcm_token',
        'firebase_credentials',
        'firebase_id_token',
        'google_access_token',
        'google_id_token',
        'id_token',
        'otp',
        'password',
        'password_confirmation',
        'provider_token',
        'remember_token',
        'secret',
        'token',
        'token_hash',
    ];

    private const IGNORED_MODEL_UPDATE_FIELDS = ['last_used_at', 'updated_at'];

    public function recordHttpAction(
        Request $request,
        ?Response $response,
        float $durationMs,
        ?Throwable $exception = null,
        ?Authenticatable $actorBeforeAction = null,
    ): void {
        if (! $this->shouldRecordHttpAction($request)) {
            return;
        }

        $route = $request->route();
        $actor = $this->currentActor($request) ?? $actorBeforeAction;
        $status = $response?->getStatusCode() ?? $this->statusFromException($exception);
        $action = $route?->getName() ?: $route?->getActionName() ?: $request->method().' '.$request->path();
        $path = $this->path($request);

        $metadata = [
            'request_payload' => $this->sanitize($request->input()),
            'route_parameters' => $this->sanitize($route?->parameters() ?? []),
        ];

        if ($exception) {
            $metadata['exception'] = [
                'type' => $exception::class,
                'message' => Str::limit($exception->getMessage(), 500),
            ];
        }

        $this->insert($this->withActor([
            'request_id' => $this->requestId($request),
            'source' => $this->source($request),
            'event' => $exception ? 'http.failed' : 'http.request',
            'action' => $this->limit($action, 160),
            'method' => $request->method(),
            'route_name' => $this->limit($route?->getName(), 160),
            'path' => $this->limit($path, 512),
            'url' => $this->url($request, $path),
            'ip_address' => $request->ip(),
            'user_agent' => Str::limit((string) $request->userAgent(), 1000),
            'response_status' => $status,
            'duration_ms' => max(0, (int) round($durationMs)),
            'metadata' => $metadata,
        ], $actor));
    }

    public function recordModelEvent(string $event, Model $model): void
    {
        if ($model instanceof AuditLog || $this->shouldIgnoreModelEvent($event, $model)) {
            return;
        }

        $request = $this->request();
        $actor = $request ? $this->currentActor($request) : Auth::user();
        $changes = $event === 'updated' ? $model->getChanges() : null;

        $keys = is_array($changes) ? array_keys($changes) : null;
        $oldValues = match ($event) {
            'created' => null,
            'updated' => $this->modelAttributes($model, $keys, true),
            default => $this->modelAttributes($model),
        };
        $newValues = match ($event) {
            'deleted', 'forceDeleted' => null,
            'updated' => $this->modelAttributes($model, $keys),
            default => $this->modelAttributes($model),
        };

        $metadata = [
            'model' => $model::class,
        ];

        if ($request) {
            $metadata['request'] = [
                'request_id' => $this->requestId($request),
                'source' => $this->source($request),
                'method' => $request->method(),
                'route_name' => $this->limit($request->route()?->getName(), 160),
                'path' => $this->limit($this->path($request), 512),
            ];
        }

        $path = $request ? $this->path($request) : null;

        $this->insert($this->withActor([
            'request_id' => $request ? $this->requestId($request) : null,
            'source' => $request ? $this->source($request) : (app()->runningInConsole() ? 'console' : 'system'),
            'event' => 'model.'.$event,
            'action' => $this->limit(class_basename($model).'.'.$event, 160),
            'auditable_type' => $model::class,
            'auditable_id' => $this->numericKey($model->getKey()),
            'method' => $request?->method(),
            'route_name' => $this->limit($request?->route()?->getName(), 160),
            'path' => $this->limit($path, 512),
            'url' => $request ? $this->url($request, $path) : null,
            'ip_address' => $request?->ip(),
            'user_agent' => $request ? Str::limit((string) $request->userAgent(), 1000) : null,
            'metadata' => $metadata,
            'old_values' => $oldValues,
            'new_values' => $newValues,
        ], $actor));
    }

    private function shouldRecordHttpAction(Request $request): bool
    {
        if ($request->isMethod('GET') || $request->isMethod('HEAD') || $request->isMethod('OPTIONS')) {
            return false;
        }

        return ! $request->is('up');
    }

    private function shouldIgnoreModelEvent(string $event, Model $model): bool
    {
        if ($event !== 'updated') {
            return false;
        }

        $changedKeys = array_keys($model->getChanges());
        if ($changedKeys === []) {
            return true;
        }

        if ($model instanceof ApiToken && $this->onlyIgnoredFieldsChanged($changedKeys)) {
            return true;
        }

        return $changedKeys === ['updated_at'];
    }

    /**
     * @param  array<int, string>  $changedKeys
     */
    private function onlyIgnoredFieldsChanged(array $changedKeys): bool
    {
        return empty(array_diff($changedKeys, self::IGNORED_MODEL_UPDATE_FIELDS));
    }

    /**
     * @param  array<int, string>|null  $keys
     * @return array<string, mixed>
     */
    private function modelAttributes(Model $model, ?array $keys = null, bool $original = false): array
    {
        $attributes = $original ? $model->getOriginal() : $model->getAttributes();

        if ($keys !== null) {
            $attributes = Arr::only($attributes, $keys);
        }

        $clean = $this->sanitize($attributes);

        if ($model instanceof AppSetting && $this->isSensitiveKey((string) ($attributes['key'] ?? ''))) {
            $clean['value'] = self::REDACTED;
        }

        return $clean;
    }

    /**
     * @param  array<string, mixed>  $data
     * @return array<string, mixed>
     */
    private function withActor(array $data, ?Authenticatable $actor): array
    {
        if (! $actor) {
            return $data;
        }

        return $data + [
            'actor_type' => $actor::class,
            'actor_id' => $this->numericKey($actor->getAuthIdentifier()),
            'actor_role' => data_get($actor, 'role'),
            'actor_name' => $this->limit(data_get($actor, 'name'), 160),
            'actor_email' => $this->limit(data_get($actor, 'email'), 190),
        ];
    }

    /**
     * @param  array<string, mixed>  $data
     */
    private function insert(array $data): void
    {
        $jsonColumns = ['metadata', 'old_values', 'new_values'];

        foreach ($jsonColumns as $column) {
            if (array_key_exists($column, $data)) {
                $data[$column] = $data[$column] === null
                    ? null
                    : json_encode($data[$column], JSON_UNESCAPED_SLASHES | JSON_INVALID_UTF8_SUBSTITUTE);
            }
        }

        try {
            DB::table('audit_logs')->insert($data + [
                'request_id' => null,
                'source' => 'system',
                'event' => 'unknown',
                'action' => null,
                'actor_type' => null,
                'actor_id' => null,
                'actor_role' => null,
                'actor_name' => null,
                'actor_email' => null,
                'auditable_type' => null,
                'auditable_id' => null,
                'method' => null,
                'route_name' => null,
                'path' => null,
                'url' => null,
                'ip_address' => null,
                'user_agent' => null,
                'response_status' => null,
                'duration_ms' => null,
                'metadata' => null,
                'old_values' => null,
                'new_values' => null,
                'created_at' => now(),
            ]);
        } catch (Throwable $error) {
            report($error);
        }
    }

    /**
     * @param  array<string, mixed>  $value
     * @return array<string, mixed>
     */
    private function sanitize(array $value): array
    {
        return $this->sanitizeArray($value);
    }

    /**
     * @param  array<string, mixed>  $values
     * @return array<string, mixed>
     */
    private function sanitizeArray(array $values): array
    {
        $clean = [];

        foreach ($values as $key => $value) {
            $key = (string) $key;
            $clean[$key] = $this->isSensitiveKey($key)
                ? self::REDACTED
                : $this->normalizeValue($value);
        }

        return $clean;
    }

    private function normalizeValue(mixed $value): mixed
    {
        if ($value instanceof DateTimeInterface) {
            return $value->format(DateTimeInterface::ATOM);
        }

        if ($value instanceof Model) {
            return [
                'type' => $value::class,
                'id' => $this->numericKey($value->getKey()),
            ];
        }

        if ($value instanceof UnitEnum) {
            return $value instanceof \BackedEnum ? $value->value : $value->name;
        }

        if (is_array($value)) {
            return $this->sanitizeArray($value);
        }

        if (is_object($value)) {
            return method_exists($value, '__toString') ? (string) $value : $value::class;
        }

        if (is_string($value)) {
            return Str::limit($value, 2000);
        }

        return $value;
    }

    private function isSensitiveKey(string $key): bool
    {
        $normalized = Str::of($key)->lower()->replace(['-', ' '], '_')->toString();

        foreach (self::SENSITIVE_KEYS as $sensitive) {
            if ($normalized === $sensitive || Str::contains($normalized, '_'.$sensitive) || Str::contains($normalized, $sensitive.'_')) {
                return true;
            }
        }

        return false;
    }

    private function currentActor(Request $request): ?Authenticatable
    {
        $auditActor = $request->attributes->get('audit_actor');

        if ($auditActor instanceof Authenticatable) {
            return $auditActor;
        }

        return $request->user() ?: Auth::user();
    }

    private function requestId(Request $request): string
    {
        if (! $request->attributes->has('audit_request_id')) {
            $request->attributes->set(
                'audit_request_id',
                $this->limit($request->headers->get('X-Request-Id') ?: (string) Str::uuid(), 64),
            );
        }

        return (string) $request->attributes->get('audit_request_id');
    }

    private function request(): ?Request
    {
        return app()->bound('request') ? app('request') : null;
    }

    private function source(?Request $request): string
    {
        if (! $request) {
            return app()->runningInConsole() ? 'console' : 'system';
        }

        return match (true) {
            $request->is('api/*') => 'api',
            $request->is('dashboard*') || $request->is('admin/*') => 'admin',
            default => 'web',
        };
    }

    private function path(Request $request): string
    {
        return $request->route()?->uri() ?: $request->path();
    }

    private function url(Request $request, ?string $path): string
    {
        return rtrim($request->getSchemeAndHttpHost(), '/').'/'.ltrim($path ?: $request->path(), '/');
    }

    private function statusFromException(?Throwable $exception): int
    {
        if ($exception instanceof HttpExceptionInterface) {
            return $exception->getStatusCode();
        }

        return $exception ? 500 : 0;
    }

    private function numericKey(mixed $key): ?int
    {
        return is_numeric($key) ? (int) $key : null;
    }

    private function limit(?string $value, int $limit): ?string
    {
        return $value === null ? null : Str::limit($value, $limit, '');
    }
}
