<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>DiscountLink Operations</title>
    <style>
        body{font-family:Inter,Arial,sans-serif;margin:0;background:#f6f7f9;color:#1f2937}.wrap{max-width:1180px;margin:0 auto;padding:28px}.topbar{display:flex;align-items:center;justify-content:space-between;gap:16px;margin-bottom:16px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:12px}.card{background:white;border:1px solid #e5e7eb;border-radius:8px;padding:16px}.label{font-size:12px;color:#6b7280;text-transform:uppercase}.value{font-size:28px;font-weight:700;margin-top:6px}table{width:100%;border-collapse:collapse;background:white;border:1px solid #e5e7eb;border-radius:8px;overflow:hidden}th,td{text-align:left;padding:10px;border-bottom:1px solid #e5e7eb;font-size:14px}h1,h2{margin:0 0 16px}.topbar h1{margin:0}.section{margin-top:26px}.status{font-weight:700;color:#0f766e}.logout{border:1px solid #d1d5db;background:#fff;border-radius:6px;color:#374151;cursor:pointer;font-weight:700;padding:9px 12px}
    </style>
</head>
<body>
<div class="wrap">
    <div class="topbar">
        <h1>DiscountLink Operations</h1>
        <form method="post" action="{{ route('admin.logout') }}">
            @csrf
            <button class="logout" type="submit">Sign out</button>
        </form>
    </div>
    <div class="grid">
        @foreach($stats as $label => $value)
            <div class="card"><div class="label">{{ str_replace('_', ' ', $label) }}</div><div class="value">{{ is_numeric($value) ? number_format($value, 2) : $value }}</div></div>
        @endforeach
    </div>
    <div class="section"><h2>Recent Orders</h2><table><tr><th>Ref</th><th>Buyer</th><th>Seller</th><th>Shop</th><th>Status</th><th>Total</th><th>Deliverer</th></tr>@foreach($orders as $order)<tr><td>{{ $order->reference }}</td><td>{{ $order->buyer?->name }}</td><td>{{ $order->seller?->name }}</td><td>{{ $order->shop?->name }}</td><td class="status">{{ $order->status }}</td><td>{{ number_format($order->grand_total,2) }}</td><td>{{ $order->deliveryAssignment?->deliverer?->name ?? 'Unassigned' }}</td></tr>@endforeach</table></div>
    <div class="section"><h2>Dispatch Follow Ups</h2><table><tr><th>Order</th><th>Status</th><th>Deliverer</th><th>Accepted</th><th>Completed</th></tr>@foreach($deliveries as $delivery)<tr><td>{{ $delivery->order?->reference }}</td><td class="status">{{ $delivery->status }}</td><td>{{ $delivery->deliverer?->name ?? 'Broadcast' }}</td><td>{{ $delivery->accepted_at }}</td><td>{{ $delivery->completed_at }}</td></tr>@endforeach</table></div>
    <div class="section"><h2>Payments and Disbursements</h2><table><tr><th>Order</th><th>Type</th><th>Status</th><th>Amount</th><th>Phone</th><th>Provider Ref</th></tr>@foreach($payments as $payment)<tr><td>{{ $payment->order?->reference }}</td><td>{{ $payment->type }}</td><td class="status">{{ $payment->status }}</td><td>{{ number_format($payment->amount,2) }}</td><td>{{ $payment->phone }}</td><td>{{ $payment->provider_reference }}</td></tr>@endforeach</table></div>
</div>
</body>
</html>
