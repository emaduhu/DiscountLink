<?php

namespace Tests\Feature;

use App\Models\Conversation;
use App\Models\Message;
use App\Models\User;
use App\Services\ApiTokenService;
use Illuminate\Foundation\Testing\RefreshDatabase;
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
}
