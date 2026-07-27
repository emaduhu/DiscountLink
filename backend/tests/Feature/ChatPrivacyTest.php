<?php

namespace Tests\Feature;

use App\Models\Conversation;
use App\Models\Message;
use App\Models\User;
use App\Services\ApiTokenService;
use App\Services\FcmService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Mockery;
use Tests\TestCase;

class ChatPrivacyTest extends TestCase
{
    use RefreshDatabase;

    public function test_other_users_cannot_see_or_interact_with_a_private_chat(): void
    {
        $first = User::factory()->create();
        $second = User::factory()->create();
        $outsider = User::factory()->create();
        $conversation = Conversation::create([
            'user_one_id' => $first->id,
            'user_two_id' => $second->id,
        ]);
        Message::create([
            'conversation_id' => $conversation->id,
            'sender_id' => $first->id,
            'body' => 'Private message',
        ]);
        $token = app(ApiTokenService::class)->issue($outsider);

        $this->withToken($token)->getJson('/api/conversations')
            ->assertOk()
            ->assertJsonCount(0, 'conversations');

        $privateRoutes = [
            ['get', "/api/conversations/{$conversation->id}/messages", []],
            ['post', "/api/conversations/{$conversation->id}/messages", ['body' => 'Intrusion']],
            ['post', "/api/conversations/{$conversation->id}/discount-links", ['discount_price' => 1]],
            ['post', "/api/conversations/{$conversation->id}/report", ['reason' => 'Other']],
            ['post', "/api/conversations/{$conversation->id}/block", []],
            ['post', "/api/conversations/{$conversation->id}/unblock", []],
        ];

        foreach ($privateRoutes as [$method, $uri, $body]) {
            $response = $method === 'get'
                ? $this->withToken($token)->getJson($uri)
                : $this->withToken($token)->postJson($uri, $body);

            $response->assertNotFound();
        }

        $this->assertDatabaseMissing('messages', [
            'conversation_id' => $conversation->id,
            'sender_id' => $outsider->id,
        ]);
    }

    public function test_both_participants_can_read_their_private_chat(): void
    {
        $first = User::factory()->create();
        $second = User::factory()->create();
        $conversation = Conversation::create([
            'user_one_id' => $first->id,
            'user_two_id' => $second->id,
        ]);
        Message::create([
            'conversation_id' => $conversation->id,
            'sender_id' => $first->id,
            'body' => 'Participant-only message',
        ]);

        foreach ([$first, $second] as $participant) {
            $token = app(ApiTokenService::class)->issue($participant);
            $this->withToken($token)
                ->getJson("/api/conversations/{$conversation->id}/messages")
                ->assertOk()
                ->assertJsonPath('messages.data.0.body', 'Participant-only message');
        }
    }

    public function test_chat_message_sends_fcm_notification_to_receiver_device(): void
    {
        $sender = User::factory()->create(['name' => 'Asha Seller']);
        $receiver = User::factory()->create([
            'name' => 'Juma Buyer',
            'fcm_token' => 'receiver-device-token',
        ]);
        $conversation = Conversation::create([
            'user_one_id' => $sender->id,
            'user_two_id' => $receiver->id,
        ]);
        $token = app(ApiTokenService::class)->issue($sender);
        $fcm = Mockery::mock(FcmService::class);
        $this->app->instance(FcmService::class, $fcm);

        $fcm->shouldReceive('sendToUser')
            ->once()
            ->withArgs(function (User $user, string $title, string $body, array $data) use ($receiver, $sender, $conversation) {
                return $user->is($receiver)
                    && $title === 'New message from Asha Seller'
                    && $body === 'Hello, is this still available?'
                    && $data['type'] === 'chat_message'
                    && $data['route'] === 'chat'
                    && $data['conversation_id'] === (string) $conversation->id
                    && $data['unread_count'] === '1'
                    && $data['sender_id'] === (string) $sender->id
                    && $data['sender_name'] === 'Asha Seller';
            })
            ->andReturn(true);

        $this->withToken($token)
            ->postJson("/api/conversations/{$conversation->id}/messages", [
                'body' => 'Hello, is this still available?',
            ])
            ->assertCreated()
            ->assertJsonPath('message.body', 'Hello, is this still available?');
    }
}
