<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>DiscountLink Operations</title>
    <style>
        :root{--bg:#f4f6f8;--panel:#fff;--line:#e4e7ec;--text:#182230;--muted:#667085;--soft:#f9fafb;--brand:#f97316;--brand-dark:#c2410c;--ok:#027a48;--bad:#b42318;--blue:#175cd3}*{box-sizing:border-box}body{font-family:Inter,Arial,sans-serif;margin:0;background:var(--bg);color:var(--text)}.wrap{max-width:1480px;margin:0 auto;padding:24px}.topbar{position:sticky;top:0;z-index:20;display:flex;align-items:center;justify-content:space-between;gap:18px;margin:-24px -24px 20px;padding:18px 24px;background:rgba(255,255,255,.94);border-bottom:1px solid var(--line);backdrop-filter:blur(10px)}.brand{display:flex;align-items:center;gap:12px}.mark{display:grid;place-items:center;width:42px;height:42px;border-radius:12px;background:linear-gradient(135deg,#ff8a1f,#f04438);color:#fff;font-weight:900}.topbar h1{font-size:22px;margin:0}.refresh{font-size:13px;color:var(--muted);margin-top:3px}.layout{display:grid;grid-template-columns:220px minmax(0,1fr);gap:20px;align-items:start}.side-menu{position:sticky;top:92px;z-index:8;max-height:calc(100vh - 112px);overflow:auto;background:#fff;border:1px solid var(--line);border-radius:8px;padding:12px;box-shadow:0 1px 2px rgba(16,24,40,.04)}.side-title{padding:4px 8px 10px}.side-title .label{display:block}.nav{display:flex;flex-direction:column;gap:4px}.nav a{display:flex;align-items:center;justify-content:space-between;gap:8px;color:#344054;text-decoration:none;border:1px solid transparent;border-radius:7px;font-size:13px;font-weight:800;padding:9px 10px}.nav a:hover{background:#f9fafb;border-color:var(--line)}.nav a.active{background:#fff7ed;border-color:#fed7aa;color:var(--brand-dark)}.main-content{min-width:0}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:12px}.two{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:14px}.card{background:var(--panel);border:1px solid var(--line);border-radius:8px;padding:16px;box-shadow:0 1px 2px rgba(16,24,40,.04)}.grid .card{min-height:96px}.label{font-size:11px;letter-spacing:.04em;color:var(--muted);text-transform:uppercase;font-weight:800}.value{font-size:27px;font-weight:900;margin-top:8px;color:#111827}.flash{background:#ecfdf3;border:1px solid #abefc6;border-radius:8px;color:#067647;margin-bottom:14px;padding:11px 13px;font-weight:800}.section{margin-top:26px;scroll-margin-top:96px}.section h2{font-size:18px;margin:0}.section-head{display:flex;align-items:center;justify-content:space-between;gap:12px;margin-bottom:12px}.tools{display:flex;align-items:flex-end;gap:8px;flex-wrap:wrap}.tools input,.tools select{width:auto;min-width:150px;margin:0}.tools input{min-width:260px}.search-wrap{position:relative}.search-wrap input{padding-right:40px}.clear-search{display:none;position:absolute;right:4px;top:50%;width:30px;height:30px;min-width:30px;padding:0;transform:translateY(-50%);border:0;background:transparent;color:#667085;font-size:18px;line-height:1}.search-wrap.has-value .clear-search{display:inline-grid;place-items:center}.tools.is-searching input{background:#fffbeb;border-color:#fbbf24}.pagination{display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap;margin-top:10px;color:var(--muted);font-size:13px}.pagination nav{display:flex;align-items:center;gap:4px;flex-wrap:wrap}.pagination a,.pagination span[aria-current] span,.pagination span[aria-disabled] span{display:inline-flex;align-items:center;justify-content:center;min-width:34px;height:34px;border:1px solid var(--line);border-radius:7px;background:#fff;color:#344054;padding:0 10px;text-decoration:none;font-weight:800}.pagination span[aria-current] span{background:var(--brand);border-color:var(--brand);color:#fff}.pagination span[aria-disabled] span{color:#98a2b3;background:#f8fafc}.empty{padding:18px;color:var(--muted);font-weight:800;background:#fff;border:1px solid var(--line);border-radius:8px}.table-wrap{overflow-x:auto;background:#fff;border:1px solid var(--line);border-radius:8px;box-shadow:0 1px 2px rgba(16,24,40,.04);padding-bottom:2px;-webkit-overflow-scrolling:touch}.table-wrap:focus-within{outline:2px solid #fed7aa;outline-offset:2px}table{width:100%;min-width:980px;border-collapse:separate;border-spacing:0;background:white;table-layout:auto}#products table{min-width:1220px}#reports table{min-width:1180px}#chats table{min-width:1040px}#orders table,#deliveries table,#payments table{min-width:1080px}th,td{text-align:left;padding:13px 14px;border-bottom:1px solid var(--line);font-size:14px;line-height:1.4;vertical-align:top;overflow-wrap:anywhere}th{position:static;background:#f8fafc;color:#475467;font-size:12px;text-transform:uppercase;letter-spacing:.04em;white-space:nowrap;border-bottom:2px solid #d0d5dd;box-shadow:inset 0 -1px 0 #eef2f6}tr:first-child + tr td{padding-top:16px}td:last-child,th:last-child{width:1%;white-space:nowrap}td:nth-last-child(2),th:nth-last-child(2){white-space:nowrap}.table-wrap td:first-child{min-width:190px}.table-wrap td:nth-child(2){min-width:120px}#products td:nth-child(1){min-width:240px}#products td:nth-child(2),#products td:nth-child(3){min-width:180px}#reports td:nth-child(1){min-width:240px}#reports td:nth-child(2),#reports td:nth-child(3),#reports td:nth-child(4){min-width:180px}#deliveries td:nth-child(4){min-width:220px}tr:last-child td{border-bottom:0}tbody tr:hover{background:#fffaf5}.status{font-weight:900;color:var(--ok)}.blocked{color:var(--bad);font-weight:900}.muted{color:var(--muted);font-size:12px;line-height:1.45;overflow-wrap:anywhere}.logout,button{border:1px solid #d0d5dd;background:#fff;border-radius:7px;color:#344054;cursor:pointer;font-weight:900;padding:9px 12px;white-space:nowrap}button:hover,.logout:hover{border-color:#98a2b3;background:#f9fafb}button.primary{background:var(--brand);border-color:var(--brand);color:white}button.primary:hover{background:var(--brand-dark);border-color:var(--brand-dark)}button.danger{border-color:#fecdca;background:#fff7f6;color:var(--bad)}input,select,textarea{border:1px solid #d0d5dd;border-radius:7px;box-sizing:border-box;margin:0 0 11px;padding:10px 11px;width:100%;font:inherit;background:#fff}input:focus,select:focus,textarea:focus{outline:2px solid #fed7aa;border-color:var(--brand)}textarea{min-height:92px;resize:vertical}.actions{display:flex;gap:8px;flex-wrap:nowrap;align-items:flex-start}.actions form{margin:0}.badge{display:inline-block;border-radius:999px;padding:4px 9px;background:#eff6ff;color:var(--blue);font-size:12px;font-weight:900;white-space:nowrap}.pill{display:inline-flex;align-items:center;border-radius:999px;padding:4px 9px;background:#f2f4f7;color:#344054;font-size:12px;font-weight:900;white-space:nowrap}@media(max-width:900px){.wrap{padding:16px}.topbar{position:static;margin:-16px -16px 16px;padding:16px;align-items:flex-start}.topbar,.brand{flex-direction:column}.topbar form{width:100%}.logout{width:100%}.layout{display:block}.side-menu{position:sticky;top:0;z-index:15;max-height:none;margin:0 0 16px;padding:10px;border-radius:8px}.side-title{display:none}.nav{flex-direction:row;overflow-x:auto;gap:8px;padding-bottom:2px}.nav a{flex:0 0 auto;white-space:nowrap;background:#fff;border-color:var(--line)}.value{font-size:23px}.section{scroll-margin-top:86px}.section-head{align-items:stretch;flex-direction:column}.tools input,.tools select,.tools button,.search-wrap{width:100%;min-width:0}.table-wrap{border-radius:8px;margin-inline:-4px}table{min-width:920px}#products table,#reports table{min-width:1120px}}
    </style>
</head>
<body>
<div class="wrap">
    <div class="topbar">
        <div class="brand">
            <div class="mark">DL</div>
            <div>
                <h1>DiscountLink Operations</h1>
                <div class="refresh" data-refresh-status data-loaded-at="{{ now()->format('Y-m-d H:i:s') }}">Last loaded {{ now()->format('Y-m-d H:i:s') }}.</div>
            </div>
        </div>
        <form method="post" action="{{ route('admin.logout') }}">
            @csrf
            <button class="logout" type="submit">Sign out</button>
        </form>
    </div>
    @if(session('status'))<div class="flash">{{ session('status') }}</div>@endif
    @php($pageOptions = [10, 25, 50, 100])
    <div class="layout">
        <aside class="side-menu" aria-label="Dashboard pages">
            <div class="side-title"><span class="label">Pages</span></div>
            <nav class="nav" aria-label="Dashboard sections">
                <a class="{{ $activePage === 'settings' ? 'active' : '' }}" href="{{ route('dashboard', ['page' => 'settings']) }}">Settings</a>
                <a class="{{ $activePage === 'users' ? 'active' : '' }}" href="{{ route('dashboard', ['page' => 'users']) }}">Users</a>
                <a class="{{ $activePage === 'products' ? 'active' : '' }}" href="{{ route('dashboard', ['page' => 'products']) }}">Products</a>
                <a class="{{ $activePage === 'reports' ? 'active' : '' }}" href="{{ route('dashboard', ['page' => 'reports']) }}">Chat reports</a>
                <a class="{{ $activePage === 'chats' ? 'active' : '' }}" href="{{ route('dashboard', ['page' => 'chats']) }}">Chat moderation</a>
                <a class="{{ $activePage === 'notifications' ? 'active' : '' }}" href="{{ route('dashboard', ['page' => 'notifications']) }}">Notifications</a>
                <a class="{{ $activePage === 'orders' ? 'active' : '' }}" href="{{ route('dashboard', ['page' => 'orders']) }}">Orders</a>
                <a class="{{ $activePage === 'deliveries' ? 'active' : '' }}" href="{{ route('dashboard', ['page' => 'deliveries']) }}">Deliveries</a>
                <a class="{{ $activePage === 'payments' ? 'active' : '' }}" href="{{ route('dashboard', ['page' => 'payments']) }}">Payments</a>
            </nav>
        </aside>
        <main class="main-content">
    <div class="grid">
        @foreach($stats as $label => $value)
            <div class="card"><div class="label">{{ str_replace('_', ' ', $label) }}</div><div class="value">{{ is_numeric($value) ? number_format($value, 2) : $value }}</div></div>
        @endforeach
    </div>
    @if($activePage === 'settings')
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
        <div class="card">
            <h2>Shop Registration Fee</h2>
            <form method="post" action="{{ route('dashboard.shop-registration-fee') }}">
                @csrf
                <label class="label">Fee amount (TZS)</label>
                <input name="shop_registration_fee_amount" type="number" min="0" step="0.01" value="{{ $settings['shop_registration_fee_amount'] }}">
                <div class="muted">Each new seller shop pays this amount via ClickPesa USSD before the shop is active. Set 0 to waive the fee.</div>
                <button class="primary" type="submit">Save registration fee</button>
            </form>
        </div>
        <div class="card">
            <h2>Checkout Service Fee</h2>
            <form method="post" action="{{ route('dashboard.service-fee') }}">
                @csrf
                <label class="label">Service fee percentage</label>
                <input name="service_fee_percentage" type="number" min="0" max="100" step="0.01" value="{{ $settings['service_fee_percentage'] }}">
                <div class="muted">Calculated from the products total only. Delivery is not included in the service fee base.</div>
                <button class="primary" type="submit">Save service fee</button>
            </form>
        </div>
    </div>
    @endif
    @if($activePage === 'users')
    <div id="users" class="section"><div class="section-head"><h2>Users</h2><form class="tools" method="get" action="{{ route('dashboard', ['page' => 'users']) }}"><input name="users_q" value="{{ $filters['users_q'] }}" placeholder="Search users"><select name="users_per_page">@foreach($pageOptions as $option)<option value="{{ $option }}" @selected($perPage['users_per_page'] === $option)>{{ $option }} per page</option>@endforeach</select></form></div><div class="table-wrap"><table><tr><th>Name</th><th>Role</th><th>Phone</th><th>Status</th><th>Action</th></tr>@forelse($users as $user)<tr><td>{{ $user->name }}<div class="muted">{{ $user->email }}</div></td><td><span class="pill">{{ $user->role }}</span></td><td>{{ $user->phone }}</td><td class="{{ $user->is_active ? 'status' : 'blocked' }}">{{ $user->is_active ? 'Active' : 'Blocked' }}</td><td><form method="post" action="{{ route('dashboard.users.toggle', $user) }}">@csrf<button type="submit">{{ $user->is_active ? 'Block' : 'Unblock' }}</button></form></td></tr>@empty<tr><td colspan="5">No users found.</td></tr>@endforelse</table></div><div class="pagination"><span>{{ $users->total() }} result(s)</span>{{ $users->links() }}</div></div>
    @endif
    @if($activePage === 'products')
    <div id="products" class="section"><div class="section-head"><h2>Product Management</h2><form class="tools" method="get" action="{{ route('dashboard', ['page' => 'products']) }}"><input name="products_q" value="{{ $filters['products_q'] }}" placeholder="Search products"><select name="products_per_page">@foreach($pageOptions as $option)<option value="{{ $option }}" @selected($perPage['products_per_page'] === $option)>{{ $option }} per page</option>@endforeach</select></form></div><div class="table-wrap"><table><tr><th>Product</th><th>Shop</th><th>Seller</th><th>Price</th><th>Stock</th><th>Status</th><th>Action</th></tr>@forelse($products as $product)<tr><td>{{ $product->name }}<div class="muted">{{ \Illuminate\Support\Str::limit($product->description, 80) }}</div></td><td>{{ $product->shop?->name }}<div class="muted">{{ collect($product->shop?->categories ?? [$product->shop?->category])->filter()->join(', ') }}</div></td><td>{{ $product->seller?->name }}<div class="muted">{{ $product->seller?->email }}</div></td><td><span class="badge">TZS {{ number_format($product->auto_total, 2) }}</span><div class="muted">Base {{ number_format($product->price, 2) }}</div></td><td>{{ $product->stock }}</td><td class="{{ $product->is_active ? 'status' : 'blocked' }}">{{ $product->is_active ? 'Active' : 'Blocked' }}</td><td><form method="post" action="{{ route('dashboard.products.toggle', $product) }}">@csrf<button class="{{ $product->is_active ? 'danger' : '' }}" type="submit">{{ $product->is_active ? 'Block product' : 'Unblock product' }}</button></form></td></tr>@empty<tr><td colspan="7">No products found.</td></tr>@endforelse</table></div><div class="pagination"><span>{{ $products->total() }} result(s)</span>{{ $products->links() }}</div></div>
    @endif
    @if($activePage === 'reports')
    <div id="reports" class="section"><div class="section-head"><h2>Chat Reports</h2><form class="tools" method="get" action="{{ route('dashboard', ['page' => 'reports']) }}"><input name="reports_q" value="{{ $filters['reports_q'] }}" placeholder="Search reports"><select name="reports_per_page">@foreach($pageOptions as $option)<option value="{{ $option }}" @selected($perPage['reports_per_page'] === $option)>{{ $option }} per page</option>@endforeach</select></form></div><div class="table-wrap"><table><tr><th>Reason</th><th>Reporter</th><th>Reported User</th><th>Conversation</th><th>Status</th><th>Action</th></tr>@forelse($conversationReports as $report)<tr><td>{{ $report->reason }}<div class="muted">{{ \Illuminate\Support\Str::limit($report->details, 120) }}</div></td><td>{{ $report->reporter?->name }}<div class="muted">{{ $report->reporter?->email }}</div></td><td>{{ $report->reportedUser?->name }}<div class="muted">{{ $report->reportedUser?->email }}</div></td><td>#{{ $report->conversation_id }}<div class="muted">{{ $report->conversation?->userOne?->name }} / {{ $report->conversation?->userTwo?->name }}</div></td><td class="{{ $report->status === 'open' ? 'blocked' : 'status' }}">{{ ucfirst($report->status) }}</td><td><div class="actions"><form method="post" action="{{ route('dashboard.conversations.toggle', $report->conversation) }}">@csrf<button class="{{ $report->conversation?->blocked_at ? '' : 'danger' }}" type="submit">{{ $report->conversation?->blocked_at ? 'Unblock chat' : 'Block chat' }}</button></form>@if($report->status === 'open')<form method="post" action="{{ route('dashboard.conversation-reports.close', $report) }}">@csrf<button type="submit">Close report</button></form>@endif</div></td></tr>@empty<tr><td colspan="6">No reports found.</td></tr>@endforelse</table></div><div class="pagination"><span>{{ $conversationReports->total() }} result(s)</span>{{ $conversationReports->links() }}</div></div>
    @endif
    @if($activePage === 'chats')
    <div id="chats" class="section"><div class="section-head"><h2>Chat Moderation</h2><form class="tools" method="get" action="{{ route('dashboard', ['page' => 'chats']) }}"><input name="chats_q" value="{{ $filters['chats_q'] }}" placeholder="Search chats"><select name="chats_per_page">@foreach($pageOptions as $option)<option value="{{ $option }}" @selected($perPage['chats_per_page'] === $option)>{{ $option }} per page</option>@endforeach</select></form></div><div class="table-wrap"><table><tr><th>Conversation</th><th>Product</th><th>Status</th><th>Blocked By</th><th>Action</th></tr>@forelse($conversations as $conversation)<tr><td>#{{ $conversation->id }}<div class="muted">{{ $conversation->userOne?->name }} / {{ $conversation->userTwo?->name }}</div></td><td>{{ $conversation->product?->name ?? 'General chat' }}</td><td class="{{ $conversation->blocked_at ? 'blocked' : 'status' }}">{{ $conversation->blocked_at ? 'Blocked' : 'Active' }}<div class="muted">{{ $conversation->block_reason }}</div></td><td>{{ $conversation->blocker?->name ?? 'None' }}<div class="muted">{{ $conversation->blocked_at }}</div></td><td><form method="post" action="{{ route('dashboard.conversations.toggle', $conversation) }}">@csrf<button class="{{ $conversation->blocked_at ? '' : 'danger' }}" type="submit">{{ $conversation->blocked_at ? 'Unblock chat' : 'Block chat' }}</button></form></td></tr>@empty<tr><td colspan="5">No chats found.</td></tr>@endforelse</table></div><div class="pagination"><span>{{ $conversations->total() }} result(s)</span>{{ $conversations->links() }}</div></div>
    @endif
    @if($activePage === 'notifications')
    <div class="section" id="notifications"><div class="section-head"><h2>Recent Notifications</h2><form class="tools" method="get" action="{{ route('dashboard', ['page' => 'notifications']) }}"><input name="notifications_q" value="{{ $filters['notifications_q'] }}" placeholder="Search notifications"><select name="notifications_per_page">@foreach($pageOptions as $option)<option value="{{ $option }}" @selected($perPage['notifications_per_page'] === $option)>{{ $option }} per page</option>@endforeach</select></form></div><div class="table-wrap"><table><tr><th>Type</th><th>Audience</th><th>Title</th><th>Sent</th><th>When</th></tr>@forelse($notifications as $notification)<tr><td class="status">{{ $notification->type }}</td><td>{{ $notification->target_role ?? 'All' }}</td><td>{{ $notification->title }}<div class="muted">{{ $notification->body }}</div></td><td>{{ $notification->sent_count }}</td><td>{{ $notification->created_at }}</td></tr>@empty<tr><td colspan="5">No notifications found.</td></tr>@endforelse</table></div><div class="pagination"><span>{{ $notifications->total() }} result(s)</span>{{ $notifications->links() }}</div></div>
    @endif
    @if($activePage === 'orders')
    <div id="orders" class="section"><div class="section-head"><h2>Recent Orders</h2><form class="tools" method="get" action="{{ route('dashboard', ['page' => 'orders']) }}"><input name="orders_q" value="{{ $filters['orders_q'] }}" placeholder="Search orders"><select name="orders_per_page">@foreach($pageOptions as $option)<option value="{{ $option }}" @selected($perPage['orders_per_page'] === $option)>{{ $option }} per page</option>@endforeach</select></form></div><div class="table-wrap"><table><tr><th>Ref</th><th>Buyer</th><th>Seller</th><th>Shop</th><th>Status</th><th>Total</th><th>Deliverer</th></tr>@forelse($orders as $order)<tr><td>{{ $order->reference }}</td><td>{{ $order->buyer?->name }}</td><td>{{ $order->seller?->name }}</td><td>{{ $order->shop?->name }}</td><td class="status">{{ $order->status }}</td><td>{{ number_format($order->grand_total,2) }}<div class="muted">Service {{ number_format($order->service_fee_total ?? 0,2) }} @ {{ number_format($order->service_fee_rate ?? 0,2) }}%</div></td><td>{{ $order->deliveryAssignment?->deliverer?->name ?? 'Unassigned' }}</td></tr>@empty<tr><td colspan="7">No orders found.</td></tr>@endforelse</table></div><div class="pagination"><span>{{ $orders->total() }} result(s)</span>{{ $orders->links() }}</div></div>
    @endif
    @if($activePage === 'deliveries')
    <div id="deliveries" class="section"><div class="section-head"><h2>Dispatch Follow Ups</h2><form class="tools" method="get" action="{{ route('dashboard', ['page' => 'deliveries']) }}"><input name="deliveries_q" value="{{ $filters['deliveries_q'] }}" placeholder="Search deliveries"><select name="deliveries_per_page">@foreach($pageOptions as $option)<option value="{{ $option }}" @selected($perPage['deliveries_per_page'] === $option)>{{ $option }} per page</option>@endforeach</select></form></div><div class="table-wrap"><table><tr><th>Order</th><th>Status</th><th>Deliverer</th><th>Tracking</th><th>Accepted</th><th>Completed</th></tr>@forelse($deliveries as $delivery)<tr><td>{{ $delivery->order?->reference }}</td><td class="status">{{ $delivery->status }}</td><td>{{ $delivery->deliverer?->name ?? 'Broadcast' }}</td><td>@if($delivery->deliverer_latitude && $delivery->deliverer_longitude)<div>{{ $delivery->deliverer_latitude }}, {{ $delivery->deliverer_longitude }}</div><div class="muted">Updated {{ $delivery->location_updated_at?->diffForHumans() ?? 'just now' }}</div>@else<span class="muted">No location shared</span>@endif</td><td>{{ $delivery->accepted_at }}</td><td>{{ $delivery->completed_at }}</td></tr>@empty<tr><td colspan="6">No deliveries found.</td></tr>@endforelse</table></div><div class="pagination"><span>{{ $deliveries->total() }} result(s)</span>{{ $deliveries->links() }}</div></div>
    @endif
    @if($activePage === 'payments')
    <div id="payments" class="section"><div class="section-head"><h2>Payments and Disbursements</h2><form class="tools" method="get" action="{{ route('dashboard', ['page' => 'payments']) }}"><input name="payments_q" value="{{ $filters['payments_q'] }}" placeholder="Search payments"><select name="payments_per_page">@foreach($pageOptions as $option)<option value="{{ $option }}" @selected($perPage['payments_per_page'] === $option)>{{ $option }} per page</option>@endforeach</select></form></div><div class="table-wrap"><table><tr><th>Order / Shop</th><th>Type</th><th>Status</th><th>Amount</th><th>Phone</th><th>Provider Ref</th></tr>@forelse($payments as $payment)<tr><td>{{ $payment->order?->reference ?? $payment->shop?->name ?? '-' }}@if($payment->shop)<div class="muted">Shop registration</div>@endif</td><td>{{ $payment->type }}</td><td class="{{ $payment->status === 'failed' ? 'blocked' : 'status' }}">{{ $payment->status }}</td><td>{{ number_format($payment->amount,2) }}</td><td>{{ $payment->phone }}</td><td>{{ $payment->provider_reference }}</td></tr>@empty<tr><td colspan="6">No payments found.</td></tr>@endforelse</table></div><div class="pagination"><span>{{ $payments->total() }} result(s)</span>{{ $payments->links() }}</div></div>
    @endif
        </main>
    </div>
    <script>
        const refreshStatus = document.querySelector('[data-refresh-status]');
        const refreshIntervalSeconds = 30;
        let nextRefreshAt = Date.now() + (refreshIntervalSeconds * 1000);
        let pendingSearch = false;

        const hasActiveFilters = () => Array.from(document.querySelectorAll('.section-head .tools input'))
            .some((input) => input.value.trim() !== '');

        const hasFocusedField = () => document.activeElement
            && document.activeElement.matches('input, select, textarea');

        const updateRefreshStatus = (message = null) => {
            if (! refreshStatus) {
                return;
            }

            const loadedAt = refreshStatus.dataset.loadedAt;
            if (message) {
                refreshStatus.textContent = `${message} Last loaded ${loadedAt}.`;
                return;
            }

            if (pendingSearch || hasFocusedField() || hasActiveFilters()) {
                refreshStatus.textContent = `Live refresh paused. Last loaded ${loadedAt}.`;
                return;
            }

            const remaining = Math.max(1, Math.ceil((nextRefreshAt - Date.now()) / 1000));
            refreshStatus.textContent = `Live refresh in ${remaining}s. Last loaded ${loadedAt}.`;
        };

        const tickRefresh = () => {
            if (document.hidden || pendingSearch || hasFocusedField() || hasActiveFilters()) {
                nextRefreshAt = Date.now() + (refreshIntervalSeconds * 1000);
                updateRefreshStatus();
                return;
            }

            if (Date.now() >= nextRefreshAt) {
                window.location.reload();
                return;
            }

            updateRefreshStatus();
        };

        const submitFilterForm = (form) => {
            const search = form.querySelector('input[type="text"], input:not([type])');
            const perPage = form.querySelector('select');
            const url = new URL(window.location.href);
            const sectionId = form.action.split('#')[1] || form.closest('.section')?.id || '';

            if (search) {
                const value = search.value.trim();
                if (value === '') {
                    url.searchParams.delete(search.name);
                } else {
                    url.searchParams.set(search.name, value);
                }

                url.searchParams.delete(search.name.replace(/_q$/, '_page'));
            }

            if (perPage) {
                url.searchParams.set(perPage.name, perPage.value);
            }

            if (sectionId) {
                url.searchParams.set('page', sectionId);
            }

            url.hash = '';
            pendingSearch = true;
            form.classList.add('is-searching');
            updateRefreshStatus('Searching...');
            window.location.assign(url.toString());
        };

        document.querySelectorAll('.section-head .tools').forEach((form) => {
            const search = form.querySelector('input[type="text"], input:not([type])');
            const perPage = form.querySelector('select');
            let lastSubmitted = search?.value.trim() ?? '';
            let timeout;

            form.addEventListener('submit', (event) => {
                event.preventDefault();
                submitFilterForm(form);
            });

            const submit = () => {
                if (search && search.value.trim() === lastSubmitted && document.activeElement === search) {
                    pendingSearch = false;
                    form.classList.remove('is-searching');
                    updateRefreshStatus();
                    return;
                }

                lastSubmitted = search?.value.trim() ?? '';
                submitFilterForm(form);
            };

            if (search) {
                const wrap = document.createElement('span');
                const clear = document.createElement('button');

                wrap.className = 'search-wrap';
                clear.className = 'clear-search';
                clear.type = 'button';
                clear.setAttribute('aria-label', `Clear ${search.placeholder.toLowerCase()}`);
                clear.textContent = 'x';

                search.before(wrap);
                wrap.append(search, clear);

                const syncClear = () => wrap.classList.toggle('has-value', search.value.trim() !== '');
                syncClear();

                search.addEventListener('input', () => {
                    pendingSearch = true;
                    form.classList.add('is-searching');
                    updateRefreshStatus('Searching...');
                    syncClear();
                    clearTimeout(timeout);
                    timeout = setTimeout(submit, 600);
                });

                search.addEventListener('keydown', (event) => {
                    if (event.key === 'Escape' && search.value !== '') {
                        event.preventDefault();
                        search.value = '';
                        syncClear();
                        submitFilterForm(form);
                    }
                });

                clear.addEventListener('click', () => {
                    search.value = '';
                    syncClear();
                    submitFilterForm(form);
                });
            }

            perPage?.addEventListener('change', () => submitFilterForm(form));
        });

        window.addEventListener('focus', () => {
            nextRefreshAt = Date.now() + (refreshIntervalSeconds * 1000);
            updateRefreshStatus();
        });

        document.addEventListener('visibilitychange', () => {
            nextRefreshAt = Date.now() + (refreshIntervalSeconds * 1000);
            updateRefreshStatus();
        });

        setInterval(tickRefresh, 1000);
        updateRefreshStatus();
    </script>
</div>
</body>
</html>
