<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Conversation;
use App\Models\Message;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ChatController extends Controller
{
    public function conversations(Request $request): JsonResponse
    {
        $conversations = Conversation::with(['messages', 'userOne:id,name,role,email,phone', 'userTwo:id,name,role,email,phone'])
            ->where('user_one_id', $request->user()->id)
            ->orWhere('user_two_id', $request->user()->id)
            ->latest()
            ->get();
        return response()->json(['conversations' => $conversations]);
    }

    public function contacts(Request $request): JsonResponse
    {
        $contacts = User::query()
            ->where('id', '!=', $request->user()->id)
            ->where('is_active', true)
            ->when($request->query('role'), fn ($query, $role) => $query->where('role', $role))
            ->select('id', 'name', 'role', 'email', 'phone')
            ->orderBy('role')
            ->orderBy('name')
            ->limit(50)
            ->get();

        return response()->json(['contacts' => $contacts]);
    }

    public function start(Request $request): JsonResponse
    {
        $data = $request->validate(['user_id' => ['required', 'exists:users,id'], 'order_id' => ['nullable', 'exists:orders,id']]);
        $ids = collect([$request->user()->id, (int) $data['user_id']])->sort()->values();
        $conversation = Conversation::firstOrCreate([
            'user_one_id' => $ids[0],
            'user_two_id' => $ids[1],
            'order_id' => $data['order_id'] ?? null,
        ]);
        return response()->json(['conversation' => $conversation->load(['userOne:id,name,role,email,phone', 'userTwo:id,name,role,email,phone'])], 201);
    }

    public function messages(Request $request, Conversation $conversation): JsonResponse
    {
        abort_unless(in_array($request->user()->id, [$conversation->user_one_id, $conversation->user_two_id], true), 403);
        return response()->json(['messages' => $conversation->messages()->latest()->paginate(50)]);
    }

    public function send(Request $request, Conversation $conversation): JsonResponse
    {
        abort_unless(in_array($request->user()->id, [$conversation->user_one_id, $conversation->user_two_id], true), 403);
        $data = $request->validate(['body' => ['required', 'string', 'max:4000']]);
        $message = Message::create(['conversation_id' => $conversation->id, 'sender_id' => $request->user()->id, 'body' => $data['body']]);
        return response()->json(['message' => $message], 201);
    }
}
