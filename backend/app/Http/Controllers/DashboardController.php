<?php

namespace App\Http\Controllers;

use App\Models\AppSetting;
use App\Models\Conversation;
use App\Models\ConversationReport;
use App\Models\DeliveryAssignment;
use App\Models\NotificationBroadcast;
use App\Models\Order;
use App\Models\Payment;
use App\Models\Product;
use App\Models\Shop;
use App\Models\User;
use App\Services\ClickPesaService;
use App\Services\FcmService;
use Illuminate\Contracts\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class DashboardController extends Controller
{
    public function login(Request $request): View|RedirectResponse
    {
        if (Auth::check() && Auth::user()->role === 'admin') {
            return redirect()->route('dashboard');
        }

        return view('admin-login');
    }

    public function authenticate(Request $request): RedirectResponse
    {
        $credentials = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        $throttleKey = Str::lower($credentials['email']).'|'.$request->ip();

        if (RateLimiter::tooManyAttempts($throttleKey, 5)) {
            $seconds = RateLimiter::availableIn($throttleKey);

            throw ValidationException::withMessages([
                'email' => "Too many login attempts. Try again in {$seconds} seconds.",
            ]);
        }

        if (! Auth::attempt([
            'email' => $credentials['email'],
            'password' => $credentials['password'],
            'role' => 'admin',
            'is_active' => true,
        ])) {
            RateLimiter::hit($throttleKey, 60);

            throw ValidationException::withMessages([
                'email' => 'The provided admin credentials are incorrect.',
            ]);
        }

        RateLimiter::clear($throttleKey);
        $request->session()->regenerate();

        return redirect()->intended(route('dashboard'));
    }

    public function logout(Request $request): RedirectResponse
    {
        Auth::logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('admin.login');
    }

    public function sendNotification(Request $request, FcmService $fcm): RedirectResponse
    {
        $this->authorizeAdmin();

        $data = $request->validate([
            'type' => ['required', Rule::in(['test', 'news', 'warning'])],
            'target_role' => ['nullable', Rule::in(['buyer', 'seller', 'deliverer'])],
            'title' => ['required', 'string', 'max:120'],
            'body' => ['required', 'string', 'max:500'],
        ]);

        $users = User::where('is_active', true)
            ->when($data['target_role'] ?? null, fn ($query, $role) => $query->where('role', $role))
            ->whereIn('role', ['buyer', 'seller', 'deliverer'])
            ->get();

        $sent = 0;
        foreach ($users as $user) {
            if ($fcm->sendToUser($user, $data['title'], $data['body'], [
                'type' => $data['type'],
                'target_role' => $data['target_role'] ?? 'all',
            ])) {
                $sent++;
            }
        }

        NotificationBroadcast::create([
            'admin_id' => Auth::id(),
            'type' => $data['type'],
            'target_role' => $data['target_role'] ?? null,
            'title' => $data['title'],
            'body' => $data['body'],
            'sent_count' => $sent,
        ]);

        return redirect()->route('dashboard')->with('status', "Notification queued for {$sent} device(s).");
    }

    public function toggleUser(User $user): RedirectResponse
    {
        $this->authorizeAdmin();
        abort_unless(in_array($user->role, ['buyer', 'seller', 'deliverer'], true), 422);

        $user->update(['is_active' => !$user->is_active]);

        return redirect()->route('dashboard')->with('status', $user->is_active ? 'User unblocked.' : 'User blocked.');
    }

    public function toggleProduct(Product $product): RedirectResponse
    {
        $this->authorizeAdmin();

        $product->update(['is_active' => ! $product->is_active]);

        return redirect()->route('dashboard')->with('status', $product->is_active ? 'Product unblocked.' : 'Product blocked.');
    }

    public function toggleConversation(Conversation $conversation): RedirectResponse
    {
        $this->authorizeAdmin();

        if ($conversation->blocked_at) {
            $conversation->update([
                'blocked_by_id' => null,
                'blocked_at' => null,
                'block_reason' => null,
            ]);

            return redirect()->route('dashboard')->with('status', 'Chat unblocked.');
        }

        $conversation->update([
            'blocked_by_id' => Auth::id(),
            'blocked_at' => now(),
            'block_reason' => 'Blocked by admin.',
        ]);

        return redirect()->route('dashboard')->with('status', 'Chat blocked.');
    }

    public function closeConversationReport(ConversationReport $report): RedirectResponse
    {
        $this->authorizeAdmin();

        $report->update([
            'status' => 'closed',
            'reviewed_at' => now(),
        ]);

        return redirect()->route('dashboard')->with('status', 'Chat report closed.');
    }

    public function updateCategories(Request $request): RedirectResponse
    {
        $this->authorizeAdmin();

        $data = $request->validate([
            'shop_categories' => ['required', 'string', 'max:2000'],
        ]);

        $categories = collect(preg_split('/[\r\n,]+/', $data['shop_categories']) ?: [])
            ->map(fn (string $category) => trim($category))
            ->filter()
            ->unique()
            ->values();

        abort_if($categories->isEmpty(), 422, 'Add at least one category.');

        AppSetting::put('shop_categories', $categories->implode("\n"));

        return redirect()->route('dashboard')->with('status', 'Shop categories updated.');
    }

    public function updateShopRegistrationFee(Request $request): RedirectResponse
    {
        $this->authorizeAdmin();

        $data = $request->validate([
            'shop_registration_fee_amount' => ['required', 'numeric', 'min:0', 'max:999999999'],
        ]);

        AppSetting::put('shop_registration_fee_amount', number_format((float) $data['shop_registration_fee_amount'], 2, '.', ''));

        return redirect()->route('dashboard')->with('status', 'Shop registration fee updated.');
    }

    public function updateServiceFee(Request $request): RedirectResponse
    {
        $this->authorizeAdmin();

        $data = $request->validate([
            'service_fee_percentage' => ['required', 'numeric', 'min:0', 'max:100'],
        ]);

        AppSetting::put('service_fee_percentage', number_format((float) $data['service_fee_percentage'], 2, '.', ''));

        return redirect()->route('dashboard')->with('status', 'Checkout service fee updated.');
    }

    public function resendPaymentPrompt(Payment $payment, ClickPesaService $clickPesa): RedirectResponse
    {
        $this->authorizeAdmin();
        abort_unless(in_array($payment->type, ['collection', 'shop_registration_fee'], true), 422, 'This payment cannot receive a phone prompt.');
        abort_if(in_array($payment->status, ['paid', 'success', 'completed'], true), 422, 'This payment is already complete.');
        abort_unless($payment->phone, 422, 'This payment does not have a phone number.');

        $clickPesa->requestUssdPush($payment);

        if ($payment->type === 'shop_registration_fee') {
            $payment->shop?->update(['registration_fee_status' => 'processing']);
        }

        return redirect()
            ->route('dashboard', ['page' => 'payments'])
            ->with('status', 'ClickPesa payment prompt sent again.');
    }

    public function updateOtpSettings(Request $request): RedirectResponse
    {
        $this->authorizeAdmin();

        $data = $request->validate([
            'otp_provider' => ['required', Rule::in(['beem', 'firebase', 'infobip'])],
            'beem_sender_id' => ['nullable', 'string', 'max:80'],
            'beem_base_url' => ['nullable', 'url', 'max:255'],
            'infobip_sender_id' => ['nullable', 'string', 'max:80'],
            'infobip_base_url' => ['nullable', 'url', 'max:255'],
            'firebase_project_id' => ['nullable', 'string', 'max:120'],
        ]);

        foreach ($data as $key => $value) {
            AppSetting::put($key, $value);
        }

        return redirect()->route('dashboard')->with('status', 'OTP provider settings updated.');
    }

    public function __invoke(Request $request): View|RedirectResponse
    {
        if (! Auth::check() || Auth::user()->role !== 'admin') {
            return redirect()->guest(route('admin.login'));
        }

        $dashboardPages = ['dashboard', 'charts', 'settings', 'users', 'products', 'reports', 'chats', 'notifications', 'orders', 'deliveries', 'payments'];
        $activePage = $request->query('page', 'dashboard');
        if (! in_array($activePage, $dashboardPages, true)) {
            $activePage = 'dashboard';
        }
        if ($activePage === 'charts') {
            $activePage = 'dashboard';
        }

        $usersPerPage = $this->perPage($request, 'users_per_page', 25);
        $productsPerPage = $this->perPage($request, 'products_per_page', 25);
        $reportsPerPage = $this->perPage($request, 'reports_per_page', 25);
        $chatsPerPage = $this->perPage($request, 'chats_per_page', 25);
        $notificationsPerPage = $this->perPage($request, 'notifications_per_page', 10);
        $ordersPerPage = $this->perPage($request, 'orders_per_page', 25);
        $deliveriesPerPage = $this->perPage($request, 'deliveries_per_page', 25);
        $paymentsPerPage = $this->perPage($request, 'payments_per_page', 25);

        $usersSearch = $this->search($request, 'users_q');
        $productsSearch = $this->search($request, 'products_q');
        $reportsSearch = $this->search($request, 'reports_q');
        $chatsSearch = $this->search($request, 'chats_q');
        $notificationsSearch = $this->search($request, 'notifications_q');
        $ordersSearch = $this->search($request, 'orders_q');
        $deliveriesSearch = $this->search($request, 'deliveries_q');
        $paymentsSearch = $this->search($request, 'payments_q');
        $serviceFeeRevenue = (float) Order::whereNotNull('paid_at')->sum('service_fee_total');
        $registrationFeeRevenue = (float) Payment::where('type', 'shop_registration_fee')
            ->whereIn('status', ['paid', 'success', 'completed'])
            ->sum('amount');

        return view('dashboard', [
            'stats' => [
                'users' => User::count(),
                'sellers' => User::where('role', 'seller')->count(),
                'deliverers' => User::where('role', 'deliverer')->count(),
                'buyers' => User::where('role', 'buyer')->count(),
                'shops' => Shop::count(),
                'products' => Product::count(),
                'orders' => Order::count(),
                'gmv' => Order::whereNotNull('paid_at')->sum('grand_total'),
                'registration_fee' => 'TZS '.number_format((float) AppSetting::get('shop_registration_fee_amount', '0'), 2),
                'service_fee' => number_format((float) AppSetting::get('service_fee_percentage', '0'), 2).'%',
                'service_fee_revenue' => 'TZS '.number_format($serviceFeeRevenue, 2),
                'registration_fee_revenue' => 'TZS '.number_format($registrationFeeRevenue, 2),
            ],
            'charts' => $this->dashboardCharts($serviceFeeRevenue, $registrationFeeRevenue),
            'orders' => Order::with('buyer', 'seller', 'shop', 'deliveryAssignment.deliverer')
                ->when($ordersSearch, fn ($query, string $search) => $query->where(fn ($builder) => $builder
                    ->where('reference', 'like', "%{$search}%")
                    ->orWhere('status', 'like', "%{$search}%")
                    ->orWhere('delivery_address', 'like', "%{$search}%")
                    ->orWhereHas('buyer', fn ($userQuery) => $this->userSearch($userQuery, $search))
                    ->orWhereHas('seller', fn ($userQuery) => $this->userSearch($userQuery, $search))
                    ->orWhereHas('shop', fn ($shopQuery) => $shopQuery->where('name', 'like', "%{$search}%"))
                    ->orWhereHas('deliveryAssignment.deliverer', fn ($userQuery) => $this->userSearch($userQuery, $search))))
                ->latest()
                ->paginate($ordersPerPage, ['*'], 'orders_page')
                ->withQueryString(),
            'deliveries' => DeliveryAssignment::with('order', 'deliverer')
                ->when($deliveriesSearch, fn ($query, string $search) => $query->where(fn ($builder) => $builder
                    ->where('status', 'like', "%{$search}%")
                    ->orWhereHas('order', fn ($orderQuery) => $orderQuery
                        ->where('reference', 'like', "%{$search}%")
                        ->orWhere('status', 'like', "%{$search}%")
                        ->orWhere('delivery_address', 'like', "%{$search}%"))
                    ->orWhereHas('deliverer', fn ($userQuery) => $this->userSearch($userQuery, $search))))
                ->latest()
                ->paginate($deliveriesPerPage, ['*'], 'deliveries_page')
                ->withQueryString(),
            'payments' => Payment::with('order', 'shop')
                ->when($paymentsSearch, fn ($query, string $search) => $query->where(fn ($builder) => $builder
                    ->where('type', 'like', "%{$search}%")
                    ->orWhere('status', 'like', "%{$search}%")
                    ->orWhere('phone', 'like', "%{$search}%")
                    ->orWhere('provider_reference', 'like', "%{$search}%")
                    ->orWhereHas('order', fn ($orderQuery) => $orderQuery->where('reference', 'like', "%{$search}%"))
                    ->orWhereHas('shop', fn ($shopQuery) => $shopQuery->where('name', 'like', "%{$search}%"))))
                ->latest()
                ->paginate($paymentsPerPage, ['*'], 'payments_page')
                ->withQueryString(),
            'users' => User::whereIn('role', ['buyer', 'seller', 'deliverer'])
                ->when($usersSearch, fn ($query, string $search) => $query->where(fn ($builder) => $this->userSearch($builder, $search)->orWhere('role', 'like', "%{$search}%")))
                ->latest()
                ->paginate($usersPerPage, ['*'], 'users_page')
                ->withQueryString(),
            'products' => Product::with(['shop', 'seller'])
                ->when($productsSearch, fn ($query, string $search) => $query->where(fn ($builder) => $builder
                    ->where('name', 'like', "%{$search}%")
                    ->orWhere('description', 'like', "%{$search}%")
                    ->orWhereHas('shop', fn ($shopQuery) => $shopQuery
                        ->where('name', 'like', "%{$search}%")
                        ->orWhere('category', 'like', "%{$search}%"))
                    ->orWhereHas('seller', fn ($userQuery) => $this->userSearch($userQuery, $search))))
                ->latest()
                ->paginate($productsPerPage, ['*'], 'products_page')
                ->withQueryString(),
            'conversations' => Conversation::with(['userOne', 'userTwo', 'product', 'blocker'])
                ->when($chatsSearch, fn ($query, string $search) => $query->where(fn ($builder) => $builder
                    ->where('id', is_numeric($search) ? (int) $search : 0)
                    ->orWhere('block_reason', 'like', "%{$search}%")
                    ->orWhereHas('product', fn ($productQuery) => $productQuery->where('name', 'like', "%{$search}%"))
                    ->orWhereHas('userOne', fn ($userQuery) => $this->userSearch($userQuery, $search))
                    ->orWhereHas('userTwo', fn ($userQuery) => $this->userSearch($userQuery, $search))))
                ->latest()
                ->paginate($chatsPerPage, ['*'], 'chats_page')
                ->withQueryString(),
            'conversationReports' => ConversationReport::with(['conversation.userOne', 'conversation.userTwo', 'reporter', 'reportedUser'])
                ->when($reportsSearch, fn ($query, string $search) => $query->where(fn ($builder) => $builder
                    ->where('reason', 'like', "%{$search}%")
                    ->orWhere('details', 'like', "%{$search}%")
                    ->orWhere('status', 'like', "%{$search}%")
                    ->orWhereHas('reporter', fn ($userQuery) => $this->userSearch($userQuery, $search))
                    ->orWhereHas('reportedUser', fn ($userQuery) => $this->userSearch($userQuery, $search))
                    ->orWhereHas('conversation.userOne', fn ($userQuery) => $this->userSearch($userQuery, $search))
                    ->orWhereHas('conversation.userTwo', fn ($userQuery) => $this->userSearch($userQuery, $search)))
                )
                ->latest()
                ->paginate($reportsPerPage, ['*'], 'reports_page')
                ->withQueryString(),
            'notifications' => NotificationBroadcast::query()
                ->when($notificationsSearch, fn ($query, string $search) => $query->where(fn ($builder) => $builder
                    ->where('type', 'like', "%{$search}%")
                    ->orWhere('target_role', 'like', "%{$search}%")
                    ->orWhere('title', 'like', "%{$search}%")
                    ->orWhere('body', 'like', "%{$search}%")))
                ->latest()
                ->paginate($notificationsPerPage, ['*'], 'notifications_page')
                ->withQueryString(),
            'settings' => [
                'otp_provider' => AppSetting::get('otp_provider', config('services.otp.provider', 'beem')),
                'beem_sender_id' => AppSetting::get('beem_sender_id', config('services.beem.sender_id')),
                'beem_base_url' => AppSetting::get('beem_base_url', config('services.beem.base_url')),
                'infobip_sender_id' => AppSetting::get('infobip_sender_id', config('services.infobip.sender_id')),
                'infobip_base_url' => AppSetting::get('infobip_base_url', config('services.infobip.base_url')),
                'firebase_project_id' => AppSetting::get('firebase_project_id', config('services.firebase.project_id')),
                'shop_registration_fee_amount' => AppSetting::get('shop_registration_fee_amount', '0.00'),
                'service_fee_percentage' => AppSetting::get('service_fee_percentage', '0.00'),
            ],
            'shopCategories' => AppSetting::get('shop_categories', "Electronics\nFashion\nGroceries\nBooks\nArt\nHome\nOther"),
            'filters' => [
                'users_q' => $usersSearch,
                'products_q' => $productsSearch,
                'reports_q' => $reportsSearch,
                'chats_q' => $chatsSearch,
                'notifications_q' => $notificationsSearch,
                'orders_q' => $ordersSearch,
                'deliveries_q' => $deliveriesSearch,
                'payments_q' => $paymentsSearch,
            ],
            'perPage' => [
                'users_per_page' => $usersPerPage,
                'products_per_page' => $productsPerPage,
                'reports_per_page' => $reportsPerPage,
                'chats_per_page' => $chatsPerPage,
                'notifications_per_page' => $notificationsPerPage,
                'orders_per_page' => $ordersPerPage,
                'deliveries_per_page' => $deliveriesPerPage,
                'payments_per_page' => $paymentsPerPage,
            ],
            'activePage' => $activePage,
        ]);
    }

    private function authorizeAdmin(): void
    {
        abort_unless(Auth::check() && Auth::user()->role === 'admin', 403);
    }

    private function perPage(Request $request, string $key, int $default): int
    {
        $value = (int) $request->query($key, $default);

        return min(max($value, 5), 100);
    }

    private function search(Request $request, string $key): ?string
    {
        $value = trim((string) $request->query($key));

        return $value === '' ? null : $value;
    }

    private function userSearch($query, string $search)
    {
        return $query
            ->where('name', 'like', "%{$search}%")
            ->orWhere('email', 'like', "%{$search}%")
            ->orWhere('phone', 'like', "%{$search}%");
    }

    private function dashboardCharts(float $serviceFeeRevenue, float $registrationFeeRevenue): array
    {
        $start = now()->subDays(13)->startOfDay();
        $orderRows = Order::query()
            ->selectRaw('DATE(created_at) as day, COUNT(*) as orders_count, COALESCE(SUM(grand_total), 0) as revenue_total')
            ->where('created_at', '>=', $start)
            ->groupBy('day')
            ->orderBy('day')
            ->get()
            ->keyBy('day');

        $dailyOrders = collect(range(13, 0))->map(function (int $offset) use ($orderRows) {
            $date = now()->subDays($offset);
            $key = $date->format('Y-m-d');
            $row = $orderRows->get($key);

            return [
                'label' => $date->format('M j'),
                'orders' => (int) ($row->orders_count ?? 0),
                'revenue' => (float) ($row->revenue_total ?? 0),
            ];
        });

        $roleCounts = User::query()
            ->whereIn('role', ['buyer', 'seller', 'deliverer'])
            ->selectRaw('role, COUNT(*) as total')
            ->groupBy('role')
            ->pluck('total', 'role');

        $orderStatuses = Order::query()
            ->selectRaw('status, COUNT(*) as total')
            ->groupBy('status')
            ->orderByDesc('total')
            ->pluck('total', 'status');

        $deliveryStatuses = DeliveryAssignment::query()
            ->selectRaw('status, COUNT(*) as total')
            ->groupBy('status')
            ->orderByDesc('total')
            ->pluck('total', 'status');

        $paymentStatuses = Payment::query()
            ->selectRaw('status, COUNT(*) as total')
            ->groupBy('status')
            ->orderByDesc('total')
            ->pluck('total', 'status');

        return [
            'dailyOrders' => $dailyOrders,
            'dailyOrdersMax' => max(1, (int) $dailyOrders->max('orders')),
            'dailyRevenueMax' => max(1, (float) $dailyOrders->max('revenue')),
            'usersByRole' => collect(['buyer', 'seller', 'deliverer'])->map(fn (string $role) => [
                'label' => ucfirst($role),
                'value' => (int) ($roleCounts[$role] ?? 0),
            ]),
            'orderStatuses' => $this->chartSegments($orderStatuses),
            'deliveryStatuses' => $this->chartSegments($deliveryStatuses),
            'paymentStatuses' => $this->chartSegments($paymentStatuses),
            'feeRevenue' => [
                ['label' => 'Service fees', 'value' => $serviceFeeRevenue],
                ['label' => 'Registration fees', 'value' => $registrationFeeRevenue],
            ],
            'lowStock' => Product::query()
                ->where('stock', '<=', 5)
                ->orderBy('stock')
                ->orderBy('name')
                ->limit(8)
                ->get(['name', 'stock']),
        ];
    }

    private function chartSegments($values)
    {
        $total = max(1, (int) $values->sum());

        return $values->map(fn ($value, string $label) => [
            'label' => Str::of($label)->replace('_', ' ')->title()->toString(),
            'value' => (int) $value,
            'percent' => round(((int) $value / $total) * 100, 1),
        ])->values();
    }
}
