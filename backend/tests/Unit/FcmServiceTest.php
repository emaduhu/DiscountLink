<?php

namespace Tests\Unit;

use App\Models\User;
use App\Services\FcmService;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\Http;
use RuntimeException;
use Tests\TestCase;

class FcmServiceTest extends TestCase
{
    public function test_it_falls_back_to_the_existing_server_key_when_firebase_v1_credentials_fail(): void
    {
        Config::set('services.firebase.project_id', 'discount-link-532cc');
        Config::set('services.firebase.credentials', 'missing-service-account.json');
        Config::set('services.fcm.server_key', 'existing-server-key');

        Http::fake([
            'https://fcm.googleapis.com/fcm/send' => Http::response(['success' => 1], 200),
        ]);

        $user = new User(['fcm_token' => 'device-token']);
        $user->id = 42;

        $sent = (new FcmService)->sendToUser($user, 'Admin notice', 'Test body', [
            'type' => 'test',
        ]);

        $this->assertTrue($sent);
        Http::assertSent(fn (Request $request) => $request->url() === 'https://fcm.googleapis.com/fcm/send'
            && $request->hasHeader('Authorization', 'key=existing-server-key')
            && $request['to'] === 'device-token'
            && $request['data'] === ['type' => 'test']);
    }

    public function test_it_reads_relative_firebase_credentials_from_the_laravel_base_path(): void
    {
        $clientEmail = 'firebase-'.bin2hex(random_bytes(4)).'@discount-link.test';
        $relativePath = 'storage/framework/testing/firebase-service-account.json';
        $absolutePath = base_path($relativePath);

        if (! is_dir(dirname($absolutePath)) && ! mkdir(dirname($absolutePath), 0775, true) && ! is_dir(dirname($absolutePath))) {
            throw new RuntimeException('Unable to create Firebase test credential directory.');
        }

        file_put_contents($absolutePath, json_encode([
            'client_email' => $clientEmail,
            'private_key' => $this->fakePrivateKey(),
        ], JSON_THROW_ON_ERROR));

        Config::set('services.firebase.project_id', 'discount-link-532cc');
        Config::set('services.firebase.credentials', $relativePath);
        Config::set('services.fcm.server_key', null);
        Cache::forget('firebase_access_token_'.md5($clientEmail));

        Http::fake([
            'https://oauth2.googleapis.com/token' => Http::response(['access_token' => 'firebase-v1-token'], 200),
            'https://fcm.googleapis.com/v1/projects/discount-link-532cc/messages:send' => Http::response(['name' => 'messages/1'], 200),
        ]);

        try {
            $user = new User(['fcm_token' => 'device-token']);
            $user->id = 43;

            $sent = (new FcmService)->sendToUser($user, 'Admin notice', 'Test body', [
                'type' => 'test',
                'attempt' => 1,
            ]);

            $this->assertTrue($sent);
            Http::assertSent(fn (Request $request) => $request->url() === 'https://oauth2.googleapis.com/token'
                && $request['grant_type'] === 'urn:ietf:params:oauth:grant-type:jwt-bearer');
            Http::assertSent(fn (Request $request) => $request->url() === 'https://fcm.googleapis.com/v1/projects/discount-link-532cc/messages:send'
                && $request->hasHeader('Authorization', 'Bearer firebase-v1-token')
                && $request['message']['token'] === 'device-token'
                && $request['message']['data'] === ['type' => 'test', 'attempt' => '1']);
        } finally {
            @unlink($absolutePath);
        }
    }

    private function fakePrivateKey(): string
    {
        $key = openssl_pkey_new([
            'private_key_bits' => 2048,
            'private_key_type' => OPENSSL_KEYTYPE_RSA,
        ]);

        if (! $key || ! openssl_pkey_export($key, $privateKey)) {
            throw new RuntimeException('Unable to generate Firebase test private key.');
        }

        return $privateKey;
    }
}
