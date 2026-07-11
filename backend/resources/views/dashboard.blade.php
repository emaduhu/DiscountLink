<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta http-equiv="refresh" content="10">
    <title>DiscountLink Operations</title>
    <style>
        :root{--bg:#f4f6f8;--panel:#fff;--line:#e4e7ec;--text:#182230;--muted:#667085;--soft:#f9fafb;--brand:#f97316;--brand-dark:#c2410c;--ok:#027a48;--bad:#b42318;--blue:#175cd3}*{box-sizing:border-box}body{font-family:Inter,Arial,sans-serif;margin:0;background:var(--bg);color:var(--text)}.wrap{max-width:1320px;margin:0 auto;padding:24px}.topbar{position:sticky;top:0;z-index:10;display:flex;align-items:center;justify-content:space-between;gap:18px;margin:-24px -24px 20px;padding:18px 24px;background:rgba(255,255,255,.94);border-bottom:1px solid var(--line);backdrop-filter:blur(10px)}.brand{display:flex;align-items:center;gap:12px}.mark{display:grid;place-items:center;width:42px;height:42px;border-radius:12px;background:linear-gradient(135deg,#ff8a1f,#f04438);color:#fff;font-weight:900}.topbar h1{font-size:22px;margin:0}.refresh{font-size:13px;color:var(--muted);margin-top:3px}.nav{display:flex;gap:8px;flex-wrap:wrap;margin:0 0 18px}.nav a{color:#344054;text-decoration:none;background:#fff;border:1px solid var(--line);border-radius:999px;font-size:13px;font-weight:800;padding:8px 12px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:12px}.two{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:14px}.card{background:var(--panel);border:1px solid var(--line);border-radius:8px;padding:16px;box-shadow:0 1px 2px rgba(16,24,40,.04)}.grid .card{min-height:96px}.label{font-size:11px;letter-spacing:.04em;color:var(--muted);text-transform:uppercase;font-weight:800}.value{font-size:27px;font-weight:900;margin-top:8px;color:#111827}.flash{background:#ecfdf3;border:1px solid #abefc6;border-radius:8px;color:#067647;margin-bottom:14px;padding:11px 13px;font-weight:800}.section{margin-top:26px;scroll-margin-top:96px}.section h2{font-size:18px;margin:0 0 12px}.table-wrap{overflow-x:auto;background:#fff;border:1px solid var(--line);border-radius:8px;box-shadow:0 1px 2px rgba(16,24,40,.04);padding-bottom:2px;-webkit-overflow-scrolling:touch}.table-wrap:focus-within{outline:2px solid #fed7aa;outline-offset:2px}table{width:100%;min-width:980px;border-collapse:separate;border-spacing:0;background:white;table-layout:auto}#products table{min-width:1220px}#reports table{min-width:1180px}#chats table{min-width:1040px}#orders table,#deliveries table,#payments table{min-width:1080px}th,td{text-align:left;padding:13px 14px;border-bottom:1px solid var(--line);font-size:14px;line-height:1.4;vertical-align:top;overflow-wrap:anywhere}th{position:static;background:#f8fafc;color:#475467;font-size:12px;text-transform:uppercase;letter-spacing:.04em;white-space:nowrap;border-bottom:2px solid #d0d5dd;box-shadow:inset 0 -1px 0 #eef2f6}tr:first-child + tr td{padding-top:16px}td:last-child,th:last-child{width:1%;white-space:nowrap}td:nth-last-child(2),th:nth-last-child(2){white-space:nowrap}.table-wrap td:first-child{min-width:190px}.table-wrap td:nth-child(2){min-width:120px}#products td:nth-child(1){min-width:240px}#products td:nth-child(2),#products td:nth-child(3){min-width:180px}#reports td:nth-child(1){min-width:240px}#reports td:nth-child(2),#reports td:nth-child(3),#reports td:nth-child(4){min-width:180px}#deliveries td:nth-child(4){min-width:220px}tr:last-child td{border-bottom:0}tbody tr:hover{background:#fffaf5}.status{font-weight:900;color:var(--ok)}.blocked{color:var(--bad);font-weight:900}.muted{color:var(--muted);font-size:12px;line-height:1.45;overflow-wrap:anywhere}.logout,button{border:1px solid #d0d5dd;background:#fff;border-radius:7px;color:#344054;cursor:pointer;font-weight:900;padding:9px 12px;white-space:nowrap}button:hover,.logout:hover{border-color:#98a2b3;background:#f9fafb}button.primary{background:var(--brand);border-color:var(--brand);color:white}button.primary:hover{background:var(--brand-dark);border-color:var(--brand-dark)}button.danger{border-color:#fecdca;background:#fff7f6;color:var(--bad)}input,select,textarea{border:1px solid #d0d5dd;border-radius:7px;box-sizing:border-box;margin:0 0 11px;padding:10px 11px;width:100%;font:inherit;background:#fff}input:focus,select:focus,textarea:focus{outline:2px solid #fed7aa;border-color:var(--brand)}textarea{min-height:92px;resize:vertical}.actions{display:flex;gap:8px;flex-wrap:nowrap;align-items:flex-start}.actions form{margin:0}.badge{display:inline-block;border-radius:999px;padding:4px 9px;background:#eff6ff;color:var(--blue);font-size:12px;font-weight:900;white-space:nowrap}.pill{display:inline-flex;align-items:center;border-radius:999px;padding:4px 9px;background:#f2f4f7;color:#344054;font-size:12px;font-weight:900;white-space:nowrap}@media(max-width:760px){.wrap{padding:16px}.topbar{position:static;margin:-16px -16px 16px;padding:16px;align-items:flex-start}.topbar,.brand{flex-direction:column}.topbar form{width:100%}.logout{width:100%}.value{font-size:23px}.table-wrap{border-radius:8px;margin-inline:-4px}table{min-width:920px}#products table,#reports table{min-width:1120px}}
    </style>
</head>
<body>
<div class="wrap">
    <div class="topbar">
        <div class="brand">
            <div class="mark">DL</div>
            <div>
                <h1>DiscountLink Operations</h1>
                <div class="refresh">Auto-refreshes every 10 seconds. Last loaded {{ now()->format('Y-m-d H:i:s') }}.</div>
            </div>
        </div>
        <form method="post" action="{{ route('admin.logout') }}">
            @csrf
            <button class="logout" type="submit">Sign out</button>
        </form>
    </div>
    @if(session('status'))<div class="flash">{{ session('status') }}</div>@endif
    <nav class="nav" aria-label="Dashboard sections">
        <a href="#settings">Settings</a>
        <a href="#users">Users</a>
        <a href="#products">Products</a>
        <a href="#reports">Chat reports</a>
        <a href="#chats">Chat moderation</a>
        <a href="#orders">Orders</a>
        <a href="#deliveries">Deliveries</a>
        <a href="#payments">Payments</a>
    </nav>
    <div class="grid">
        @foreach($stats as $label => $value)
            <div class="card"><div class="label">{{ str_replace('_', ' ', $label) }}</div><div class="value">{{ is_numeric($value) ? number_format($value, 2) : $value }}</div></div>
        @endforeach
    </div>
    <div id="settings" class="section two">
        <div class="card">
            <h2>Send Notifications</h2>
            <form method="post" action="{{ route('dashboard.notifications') }}">
                @csrf
                <label class="label">Type</label>
                <select name="type">
                    <option value="test">Test</option>
                    <option value="news">News</option>
                    <option value="warning">Warning</option>
                </select>
                <label class="label">Audience</label>
                <select name="target_role">
                    <option value="">All users</option>
                    <option value="buyer">Buyers</option>
                    <option value="seller">Sellers</option>
                    <option value="deliverer">Deliverers</option>
                </select>
                <label class="label">Title</label>
                <input name="title" value="DiscountLink update" maxlength="120">
                <label class="label">Message</label>
                <textarea name="body" maxlength="500">This is a DiscountLink notification.</textarea>
                <button class="primary" type="submit">Send notification</button>
            </form>
        </div>
        <div class="card">
            <h2>SMS / OTP Provider</h2>
            <form method="post" action="{{ route('dashboard.otp-settings') }}">
                @csrf
                <label class="label">Active provider</label>
                <select name="otp_provider">
                    @foreach(['beem' => 'Beem Africa', 'firebase' => 'Firebase', 'infobip' => 'Infobip'] as $key => $label)
                        <option value="{{ $key }}" @selected(($settings['otp_provider'] ?? 'beem') === $key)>{{ $label }}</option>
                    @endforeach
                </select>
                <label class="label">Beem sender</label>
                <input name="beem_sender_id" value="{{ $settings['beem_sender_id'] }}">
                <label class="label">Beem base URL</label>
                <input name="beem_base_url" value="{{ $settings['beem_base_url'] }}">
                <label class="label">Infobip sender</label>
                <input name="infobip_sender_id" value="{{ $settings['infobip_sender_id'] }}">
                <label class="label">Infobip base URL</label>
                <input name="infobip_base_url" value="{{ $settings['infobip_base_url'] }}">
                <label class="label">Firebase project ID</label>
                <input name="firebase_project_id" value="{{ $settings['firebase_project_id'] }}">
                <button class="primary" type="submit">Save OTP settings</button>
            </form>
        </div>
        <div class="card">
            <h2>Category Management</h2>
            <form method="post" action="{{ route('dashboard.categories') }}">
                @csrf
                <label class="label">Product / shop categories</label>
                <textarea name="shop_categories" placeholder="One category per line">{{ $shopCategories }}</textarea>
                <div class="muted">The mobile app fetches this list from the backend using /api/shop-categories.</div>
                <button class="primary" type="submit">Save categories</button>
            </form>
        </div>
    </div>
    <div id="users" class="section"><h2>Users</h2><div class="table-wrap"><table><tr><th>Name</th><th>Role</th><th>Phone</th><th>Status</th><th>Action</th></tr>@foreach($users as $user)<tr><td>{{ $user->name }}<div class="muted">{{ $user->email }}</div></td><td><span class="pill">{{ $user->role }}</span></td><td>{{ $user->phone }}</td><td class="{{ $user->is_active ? 'status' : 'blocked' }}">{{ $user->is_active ? 'Active' : 'Blocked' }}</td><td><form method="post" action="{{ route('dashboard.users.toggle', $user) }}">@csrf<button type="submit">{{ $user->is_active ? 'Block' : 'Unblock' }}</button></form></td></tr>@endforeach</table></div></div>
    <div id="products" class="section"><h2>Product Management</h2><div class="table-wrap"><table><tr><th>Product</th><th>Shop</th><th>Seller</th><th>Price</th><th>Stock</th><th>Status</th><th>Action</th></tr>@foreach($products as $product)<tr><td>{{ $product->name }}<div class="muted">{{ \Illuminate\Support\Str::limit($product->description, 80) }}</div></td><td>{{ $product->shop?->name }}<div class="muted">{{ collect($product->shop?->categories ?? [$product->shop?->category])->filter()->join(', ') }}</div></td><td>{{ $product->seller?->name }}<div class="muted">{{ $product->seller?->email }}</div></td><td><span class="badge">TZS {{ number_format($product->auto_total, 2) }}</span><div class="muted">Base {{ number_format($product->price, 2) }}</div></td><td>{{ $product->stock }}</td><td class="{{ $product->is_active ? 'status' : 'blocked' }}">{{ $product->is_active ? 'Active' : 'Blocked' }}</td><td><form method="post" action="{{ route('dashboard.products.toggle', $product) }}">@csrf<button class="{{ $product->is_active ? 'danger' : '' }}" type="submit">{{ $product->is_active ? 'Block product' : 'Unblock product' }}</button></form></td></tr>@endforeach</table></div></div>
    <div id="reports" class="section"><h2>Chat Reports</h2><div class="table-wrap"><table><tr><th>Reason</th><th>Reporter</th><th>Reported User</th><th>Conversation</th><th>Status</th><th>Action</th></tr>@foreach($conversationReports as $report)<tr><td>{{ $report->reason }}<div class="muted">{{ \Illuminate\Support\Str::limit($report->details, 120) }}</div></td><td>{{ $report->reporter?->name }}<div class="muted">{{ $report->reporter?->email }}</div></td><td>{{ $report->reportedUser?->name }}<div class="muted">{{ $report->reportedUser?->email }}</div></td><td>#{{ $report->conversation_id }}<div class="muted">{{ $report->conversation?->userOne?->name }} / {{ $report->conversation?->userTwo?->name }}</div></td><td class="{{ $report->status === 'open' ? 'blocked' : 'status' }}">{{ ucfirst($report->status) }}</td><td><div class="actions"><form method="post" action="{{ route('dashboard.conversations.toggle', $report->conversation) }}">@csrf<button class="{{ $report->conversation?->blocked_at ? '' : 'danger' }}" type="submit">{{ $report->conversation?->blocked_at ? 'Unblock chat' : 'Block chat' }}</button></form>@if($report->status === 'open')<form method="post" action="{{ route('dashboard.conversation-reports.close', $report) }}">@csrf<button type="submit">Close report</button></form>@endif</div></td></tr>@endforeach</table></div></div>
    <div id="chats" class="section"><h2>Chat Moderation</h2><div class="table-wrap"><table><tr><th>Conversation</th><th>Product</th><th>Status</th><th>Blocked By</th><th>Action</th></tr>@foreach($conversations as $conversation)<tr><td>#{{ $conversation->id }}<div class="muted">{{ $conversation->userOne?->name }} / {{ $conversation->userTwo?->name }}</div></td><td>{{ $conversation->product?->name ?? 'General chat' }}</td><td class="{{ $conversation->blocked_at ? 'blocked' : 'status' }}">{{ $conversation->blocked_at ? 'Blocked' : 'Active' }}<div class="muted">{{ $conversation->block_reason }}</div></td><td>{{ $conversation->blocker?->name ?? 'None' }}<div class="muted">{{ $conversation->blocked_at }}</div></td><td><form method="post" action="{{ route('dashboard.conversations.toggle', $conversation) }}">@csrf<button class="{{ $conversation->blocked_at ? '' : 'danger' }}" type="submit">{{ $conversation->blocked_at ? 'Unblock chat' : 'Block chat' }}</button></form></td></tr>@endforeach</table></div></div>
    <div class="section"><h2>Recent Notifications</h2><div class="table-wrap"><table><tr><th>Type</th><th>Audience</th><th>Title</th><th>Sent</th><th>When</th></tr>@foreach($notifications as $notification)<tr><td class="status">{{ $notification->type }}</td><td>{{ $notification->target_role ?? 'All' }}</td><td>{{ $notification->title }}<div class="muted">{{ $notification->body }}</div></td><td>{{ $notification->sent_count }}</td><td>{{ $notification->created_at }}</td></tr>@endforeach</table></div></div>
    <div id="orders" class="section"><h2>Recent Orders</h2><div class="table-wrap"><table><tr><th>Ref</th><th>Buyer</th><th>Seller</th><th>Shop</th><th>Status</th><th>Total</th><th>Deliverer</th></tr>@foreach($orders as $order)<tr><td>{{ $order->reference }}</td><td>{{ $order->buyer?->name }}</td><td>{{ $order->seller?->name }}</td><td>{{ $order->shop?->name }}</td><td class="status">{{ $order->status }}</td><td>{{ number_format($order->grand_total,2) }}</td><td>{{ $order->deliveryAssignment?->deliverer?->name ?? 'Unassigned' }}</td></tr>@endforeach</table></div></div>
    <div id="deliveries" class="section"><h2>Dispatch Follow Ups</h2><div class="table-wrap"><table><tr><th>Order</th><th>Status</th><th>Deliverer</th><th>Tracking</th><th>Accepted</th><th>Completed</th></tr>@foreach($deliveries as $delivery)<tr><td>{{ $delivery->order?->reference }}</td><td class="status">{{ $delivery->status }}</td><td>{{ $delivery->deliverer?->name ?? 'Broadcast' }}</td><td>@if($delivery->deliverer_latitude && $delivery->deliverer_longitude)<div>{{ $delivery->deliverer_latitude }}, {{ $delivery->deliverer_longitude }}</div><div class="muted">Updated {{ $delivery->location_updated_at?->diffForHumans() ?? 'just now' }}</div>@else<span class="muted">No location shared</span>@endif</td><td>{{ $delivery->accepted_at }}</td><td>{{ $delivery->completed_at }}</td></tr>@endforeach</table></div></div>
    <div id="payments" class="section"><h2>Payments and Disbursements</h2><div class="table-wrap"><table><tr><th>Order</th><th>Type</th><th>Status</th><th>Amount</th><th>Phone</th><th>Provider Ref</th></tr>@foreach($payments as $payment)<tr><td>{{ $payment->order?->reference }}</td><td>{{ $payment->type }}</td><td class="status">{{ $payment->status }}</td><td>{{ number_format($payment->amount,2) }}</td><td>{{ $payment->phone }}</td><td>{{ $payment->provider_reference }}</td></tr>@endforeach</table></div></div>
</div>
</body>
</html>
