<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Conversation;
use App\Models\ConversationReport;
use App\Models\DiscountLink;
use App\Models\Message;
use App\Models\Product;
use App\Models\User;
use App\Services\FcmService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Illuminate\Support\Str;

class ChatController extends Controller
{
    public function conversations(Request $request): JsonResponse
    {
        $conversations = Conversation::with(['messages', 'product.shop', 'userOne:id,name,role,email,phone', 'userTwo:id,name,role,email,phone', 'blocker:id,name,role'])
            ->forParticipant($request->user()->id)
            ->when(trim((string) $request->query('q')), function ($query, string $search) {
                $query->where(fn ($builder) => $builder
                    ->whereHas('product', fn ($productQuery) => $productQuery->where('name', 'like', "%{$search}%"))
                    ->orWhereHas('userOne', fn ($userQuery) => $userQuery->where('name', 'like', "%{$search}%")->orWhere('email', 'like', "%{$search}%"))
                    ->orWhereHas('userTwo', fn ($userQuery) => $userQuery->where('name', 'like', "%{$search}%")->orWhere('email', 'like', "%{$search}%"))
                    ->orWhereHas('messages', fn ($messageQuery) => $messageQuery->where('body', 'like', "%{$search}%")));
            })
            ->latest('updated_at');

        if ($this->shouldPaginate($request)) {
            $conversations = $conversations->paginate($this->perPage($request));
            $conversations->setCollection($this->withUnreadCounts($conversations->getCollection(), $request->user()->id));

            return response()->json(['conversations' => $conversations]);
        }

        $conversations = $conversations->get();

        return response()->json(['conversations' => $this->withUnreadCounts($conversations, $request->user()->id)]);
    }

    public function contacts(Request $request): JsonResponse
    {
        $contacts = User::query()
            ->where('id', '!=', $request->user()->id)
            ->where('is_active', true)
            ->when($request->query('role'), fn ($query, $role) => $query->where('role', $role))
            ->when(trim((string) $request->query('q')), fn ($query, string $search) => $query
                ->where(fn ($builder) => $builder
                    ->where('name', 'like', "%{$search}%")
                    ->orWhere('email', 'like', "%{$search}%")
                    ->orWhere('phone', 'like', "%{$search}%")))
            ->select('id', 'name', 'role', 'email', 'phone')
            ->orderBy('role')
            ->orderBy('name');

        return response()->json([
            'contacts' => $this->shouldPaginate($request)
                ? $contacts->paginate($this->perPage($request))
                : $contacts->limit(50)->get(),
        ]);
    }

    public function start(Request $request): JsonResponse
    {
        $data = $request->validate([
            'user_id' => ['required', 'exists:users,id'],
            'order_id' => ['nullable', 'exists:orders,id'],
            'product_id' => ['nullable', 'exists:products,id'],
        ]);
        $product = isset($data['product_id']) ? Product::find($data['product_id']) : null;
        if ($product) {
            abort_unless($product->seller_id === (int) $data['user_id'] || $product->seller_id === $request->user()->id, 422, 'This product does not belong to the selected seller.');
        }
        $ids = collect([$request->user()->id, (int) $data['user_id']])->sort()->values();
        $conversation = Conversation::firstOrCreate([
            'user_one_id' => $ids[0],
            'user_two_id' => $ids[1],
            'order_id' => $data['order_id'] ?? null,
            'product_id' => $data['product_id'] ?? null,
        ]);

        return response()->json([
            'conversation' => $this->withUnreadCount(
                $conversation->load(['product.shop', 'userOne:id,name,role,email,phone', 'userTwo:id,name,role,email,phone', 'blocker:id,name,role']),
                $request->user()->id,
            ),
        ], 201);
    }

    public function messages(Request $request, Conversation $conversation): JsonResponse
    {
        $this->ensureParticipant($request, $conversation);

        $conversation->messages()
            ->where('sender_id', '!=', $request->user()->id)
            ->whereNull('read_at')
            ->update(['read_at' => now()]);

        return response()->json([
            'conversation' => $this->withUnreadCount(
                $conversation->load(['product.shop', 'userOne:id,name,role,email,phone', 'userTwo:id,name,role,email,phone', 'blocker:id,name,role']),
                $request->user()->id,
            ),
            'messages' => $conversation->messages()
                ->when(trim((string) $request->query('q')), fn ($query, string $search) => $query
                    ->where(fn ($builder) => $builder
                        ->where('body', 'like', "%{$search}%")
                        ->orWhereHas('sender', fn ($senderQuery) => $senderQuery
                            ->where('name', 'like', "%{$search}%")
                            ->orWhere('email', 'like', "%{$search}%"))))
                ->latest()
                ->paginate($this->perPage($request, 50, 100)),
        ]);
    }

    public function createDiscountLink(Request $request, Conversation $conversation, FcmService $fcm): JsonResponse
    {
        $this->ensureParticipant($request, $conversation);
        abort_if($conversation->blocked_at, 423, 'This chat has been blocked.');
        abort_unless($request->user()->role === 'seller', 403, 'Only sellers can generate discount links.');
        abort_unless($conversation->product_id, 422, 'Start the chat from a product before generating a discount link.');

        $product = Product::with('shop')->findOrFail($conversation->product_id);
        abort_unless($product->seller_id === $request->user()->id, 403, 'You can only discount your own products.');
        abort_unless($product->is_active && $product->stock > 0, 422, 'This product is no longer available.');

        $data = $request->validate([
            'discount_price' => ['required', 'numeric', 'min:1', 'lt:'.$product->price],
            'expires_in_hours' => ['nullable', 'integer', 'min:1', 'max:168'],
        ]);

        $buyerId = $conversation->user_one_id === $request->user()->id
            ? $conversation->user_two_id
            : $conversation->user_one_id;
        $buyer = User::findOrFail($buyerId);
        abort_unless($buyer->role === 'buyer', 422, 'Discount links can only be sent to buyers.');

        $discountLink = DiscountLink::create([
            'token' => Str::random(40),
            'conversation_id' => $conversation->id,
            'product_id' => $product->id,
            'seller_id' => $request->user()->id,
            'buyer_id' => $buyer->id,
            'discount_price' => $data['discount_price'],
            'expires_at' => now()->addHours($data['expires_in_hours'] ?? 48),
        ]);

        $body = "Discount offer for {$product->name}: TZS {$discountLink->discount_price}\ndiscountlink://offer/{$discountLink->token}";
        $message = Message::create([
            'conversation_id' => $conversation->id,
            'sender_id' => $request->user()->id,
            'body' => $body,
        ]);
        $conversation->touch();
        $unreadCount = $this->unreadCountFor($conversation, $buyer->id);

        $fcm->sendToUser($buyer, 'Discount offer from '.$request->user()->name, $product->name.' is now TZS '.$discountLink->discount_price.'.', [
            'type' => 'discount_link',
            'click_action' => 'FLUTTER_NOTIFICATION_CLICK',
            'route' => 'offer',
            'conversation_id' => (string) $conversation->id,
            'unread_count' => (string) $unreadCount,
            'discount_link_id' => (string) $discountLink->id,
            'product_id' => (string) $product->id,
            'seller_id' => (string) $request->user()->id,
            'token' => $discountLink->token,
        ]);

        return response()->json([
            'discount_link' => $discountLink->load('product.shop'),
            'message' => $message,
        ], 201);
    }

    public function send(Request $request, Conversation $conversation, FcmService $fcm): JsonResponse
    {
        $this->ensureParticipant($request, $conversation);
        abort_if($conversation->blocked_at, 423, 'This chat has been blocked.');
        $data = $request->validate(['body' => ['required', 'string', 'max:4000']]);
        $message = Message::create(['conversation_id' => $conversation->id, 'sender_id' => $request->user()->id, 'body' => $data['body']]);
        $conversation->touch();
        $recipientId = $conversation->user_one_id === $request->user()->id ? $conversation->user_two_id : $conversation->user_one_id;
        $recipient = User::find($recipientId);
        if ($recipient) {
            $unreadCount = $this->unreadCountFor($conversation, $recipient->id);
            $fcm->sendToUser($recipient, 'New message from '.$request->user()->name, $message->body, [
                'type' => 'chat_message',
                'click_action' => 'FLUTTER_NOTIFICATION_CLICK',
                'route' => 'chat',
                'conversation_id' => (string) $conversation->id,
                'unread_count' => (string) $unreadCount,
                'message_id' => (string) $message->id,
                'sender_id' => (string) $request->user()->id,
                'sender_name' => $request->user()->name,
                'product_id' => (string) ($conversation->product_id ?? ''),
            ]);
        }

        return response()->json(['message' => $message], 201);
    }

    public function report(Request $request, Conversation $conversation): JsonResponse
    {
        $this->ensureParticipant($request, $conversation);

        $data = $request->validate([
            'reason' => ['required', 'string', 'max:120'],
            'details' => ['nullable', 'string', 'max:1000'],
        ]);

        $reportedUserId = $conversation->user_one_id === $request->user()->id
            ? $conversation->user_two_id
            : $conversation->user_one_id;

        $report = ConversationReport::create([
            'conversation_id' => $conversation->id,
            'reporter_id' => $request->user()->id,
            'reported_user_id' => $reportedUserId,
            'reason' => $data['reason'],
            'details' => $data['details'] ?? null,
        ]);

        return response()->json([
            'report' => $report,
            'message' => 'Chat report submitted.',
        ], 201);
    }

    public function block(Request $request, Conversation $conversation, FcmService $fcm): JsonResponse
    {
        $this->ensureParticipant($request, $conversation);

        $data = $request->validate([
            'reason' => ['nullable', 'string', 'max:500'],
        ]);

        $conversation->update([
            'blocked_by_id' => $request->user()->id,
            'blocked_at' => now(),
            'block_reason' => $data['reason'] ?? 'Blocked by chat participant.',
        ]);

        $recipient = User::find($conversation->user_one_id === $request->user()->id ? $conversation->user_two_id : $conversation->user_one_id);
        if ($recipient) {
            $fcm->sendToUser($recipient, 'Chat blocked by '.$request->user()->name, 'This conversation has been blocked.', [
                'type' => 'chat_blocked',
                'click_action' => 'FLUTTER_NOTIFICATION_CLICK',
                'route' => 'chat',
                'conversation_id' => (string) $conversation->id,
                'blocked_by_id' => (string) $request->user()->id,
            ]);
        }

        return response()->json([
            'conversation' => $conversation->load(['product.shop', 'userOne:id,name,role,email,phone', 'userTwo:id,name,role,email,phone', 'blocker:id,name,role']),
            'message' => 'Chat blocked.',
        ]);
    }

    public function unblock(Request $request, Conversation $conversation, FcmService $fcm): JsonResponse
    {
        $this->ensureParticipant($request, $conversation);
        abort_unless($conversation->blocked_by_id === $request->user()->id, 403, 'Only the user who blocked this chat can unblock it.');

        $conversation->update([
            'blocked_by_id' => null,
            'blocked_at' => null,
            'block_reason' => null,
        ]);

        $recipient = User::find($conversation->user_one_id === $request->user()->id ? $conversation->user_two_id : $conversation->user_one_id);
        if ($recipient) {
            $fcm->sendToUser($recipient, 'Chat unblocked by '.$request->user()->name, 'You can continue this conversation.', [
                'type' => 'chat_unblocked',
                'click_action' => 'FLUTTER_NOTIFICATION_CLICK',
                'route' => 'chat',
                'conversation_id' => (string) $conversation->id,
                'unblocked_by_id' => (string) $request->user()->id,
            ]);
        }

        return response()->json([
            'conversation' => $conversation->load(['product.shop', 'userOne:id,name,role,email,phone', 'userTwo:id,name,role,email,phone', 'blocker:id,name,role']),
            'message' => 'Chat unblocked.',
        ]);
    }

    /**
     * @param  Collection<int, Conversation>  $conversations
     * @return Collection<int, Conversation>
     */
    private function withUnreadCounts($conversations, int $userId)
    {
        return $conversations->map(fn (Conversation $conversation) => $this->withUnreadCount($conversation, $userId));
    }

    private function ensureParticipant(Request $request, Conversation $conversation): void
    {
        abort_unless($conversation->hasParticipant($request->user()->id), 404);
    }

    private function withUnreadCount(Conversation $conversation, int $userId): Conversation
    {
        $conversation->setAttribute('unread_count', $this->unreadCountFor($conversation, $userId));

        return $conversation;
    }

    private function unreadCountFor(Conversation $conversation, int $userId): int
    {
        return $conversation->messages()
            ->where('sender_id', '!=', $userId)
            ->whereNull('read_at')
            ->count();
    }

    private function shouldPaginate(Request $request): bool
    {
        return $request->hasAny(['page', 'per_page', 'paginate', 'q']);
    }

    private function perPage(Request $request, int $default = 20, int $max = 50): int
    {
        return min($max, max(1, (int) $request->query('per_page', $default)));
    }
}
