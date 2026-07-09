<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta http-equiv="refresh" content="10">
    <title>DiscountLink Operations</title>
    <style>
        body{font-family:Inter,Arial,sans-serif;margin:0;background:#f6f7f9;color:#1f2937}.wrap{max-width:1180px;margin:0 auto;padding:28px}.topbar{display:flex;align-items:center;justify-content:space-between;gap:16px;margin-bottom:16px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:12px}.two{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:14px}.card{background:white;border:1px solid #e5e7eb;border-radius:8px;padding:16px}.label{font-size:12px;color:#6b7280;text-transform:uppercase}.value{font-size:28px;font-weight:700;margin-top:6px}.refresh{font-size:13px;color:#6b7280;margin-top:4px}.flash{background:#ecfdf5;border:1px solid #99f6e4;border-radius:8px;color:#115e59;margin-bottom:14px;padding:10px 12px}table{width:100%;border-collapse:collapse;background:white;border:1px solid #e5e7eb;border-radius:8px;overflow:hidden}th,td{text-align:left;padding:10px;border-bottom:1px solid #e5e7eb;font-size:14px;vertical-align:top}h1,h2,h3{margin:0 0 16px}.topbar h1{margin:0}.section{margin-top:26px}.status{font-weight:700;color:#0f766e}.blocked{color:#b91c1c;font-weight:700}.muted{color:#6b7280;font-size:12px}.logout,button{border:1px solid #d1d5db;background:#fff;border-radius:6px;color:#374151;cursor:pointer;font-weight:700;padding:9px 12px}button.primary{background:#0f766e;border-color:#0f766e;color:white}input,select,textarea{border:1px solid #d1d5db;border-radius:6px;box-sizing:border-box;margin:0 0 10px;padding:9px;width:100%}textarea{min-height:82px}
    </style>
</head>
<body>
<div class="wrap">
    <div class="topbar">
        <div>
            <h1>DiscountLink Operations</h1>
            <div class="refresh">Auto-refreshes every 10 seconds. Last loaded {{ now()->format('Y-m-d H:i:s') }}.</div>
        </div>
        <form method="post" action="{{ route('admin.logout') }}">
            @csrf
            <button class="logout" type="submit">Sign out</button>
        </form>
    </div>
    @if(session('status'))<div class="flash">{{ session('status') }}</div>@endif
    <div class="grid">
        @foreach($stats as $label => $value)
            <div class="card"><div class="label">{{ str_replace('_', ' ', $label) }}</div><div class="value">{{ is_numeric($value) ? number_format($value, 2) : $value }}</div></div>
        @endforeach
    </div>
    <div class="section two">
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
                <label class="label">Shop categories</label>
                <textarea name="shop_categories" placeholder="One category per line">{{ $settings['shop_categories'] }}</textarea>
                <button class="primary" type="submit">Save OTP settings</button>
            </form>
        </div>
    </div>
    <div class="section"><h2>Users</h2><table><tr><th>Name</th><th>Role</th><th>Phone</th><th>Status</th><th>Action</th></tr>@foreach($users as $user)<tr><td>{{ $user->name }}<div class="muted">{{ $user->email }}</div></td><td>{{ $user->role }}</td><td>{{ $user->phone }}</td><td class="{{ $user->is_active ? 'status' : 'blocked' }}">{{ $user->is_active ? 'Active' : 'Blocked' }}</td><td><form method="post" action="{{ route('dashboard.users.toggle', $user) }}">@csrf<button type="submit">{{ $user->is_active ? 'Block' : 'Unblock' }}</button></form></td></tr>@endforeach</table></div>
    <div class="section"><h2>Recent Notifications</h2><table><tr><th>Type</th><th>Audience</th><th>Title</th><th>Sent</th><th>When</th></tr>@foreach($notifications as $notification)<tr><td class="status">{{ $notification->type }}</td><td>{{ $notification->target_role ?? 'All' }}</td><td>{{ $notification->title }}<div class="muted">{{ $notification->body }}</div></td><td>{{ $notification->sent_count }}</td><td>{{ $notification->created_at }}</td></tr>@endforeach</table></div>
    <div class="section"><h2>Recent Orders</h2><table><tr><th>Ref</th><th>Buyer</th><th>Seller</th><th>Shop</th><th>Status</th><th>Total</th><th>Deliverer</th></tr>@foreach($orders as $order)<tr><td>{{ $order->reference }}</td><td>{{ $order->buyer?->name }}</td><td>{{ $order->seller?->name }}</td><td>{{ $order->shop?->name }}</td><td class="status">{{ $order->status }}</td><td>{{ number_format($order->grand_total,2) }}</td><td>{{ $order->deliveryAssignment?->deliverer?->name ?? 'Unassigned' }}</td></tr>@endforeach</table></div>
    <div class="section"><h2>Dispatch Follow Ups</h2><table><tr><th>Order</th><th>Status</th><th>Deliverer</th><th>Tracking</th><th>Accepted</th><th>Completed</th></tr>@foreach($deliveries as $delivery)<tr><td>{{ $delivery->order?->reference }}</td><td class="status">{{ $delivery->status }}</td><td>{{ $delivery->deliverer?->name ?? 'Broadcast' }}</td><td>@if($delivery->deliverer_latitude && $delivery->deliverer_longitude)<div>{{ $delivery->deliverer_latitude }}, {{ $delivery->deliverer_longitude }}</div><div class="muted">Updated {{ $delivery->location_updated_at?->diffForHumans() ?? 'just now' }}</div>@else<span class="muted">No location shared</span>@endif</td><td>{{ $delivery->accepted_at }}</td><td>{{ $delivery->completed_at }}</td></tr>@endforeach</table></div>
    <div class="section"><h2>Payments and Disbursements</h2><table><tr><th>Order</th><th>Type</th><th>Status</th><th>Amount</th><th>Phone</th><th>Provider Ref</th></tr>@foreach($payments as $payment)<tr><td>{{ $payment->order?->reference }}</td><td>{{ $payment->type }}</td><td class="status">{{ $payment->status }}</td><td>{{ number_format($payment->amount,2) }}</td><td>{{ $payment->phone }}</td><td>{{ $payment->provider_reference }}</td></tr>@endforeach</table></div>
</div>
</body>
</html>
