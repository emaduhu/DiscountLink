<?php

namespace App\Http\Controllers;

use App\Models\AppSetting;
use App\Models\DeliveryAssignment;
use App\Models\NotificationBroadcast;
use App\Models\Order;
use App\Models\Payment;
use App\Models\Product;
use App\Models\Shop;
use App\Models\User;
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
            $fcm->sendToUser($user, $data['title'], $data['body'], [
                'type' => $data['type'],
                'target_role' => $data['target_role'] ?? 'all',
            ]);
            if ($user->fcm_token) {
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
            ],
            'orders' => Order::with('buyer', 'seller', 'shop', 'deliveryAssignment.deliverer')->latest()->limit(25)->get(),
            'deliveries' => DeliveryAssignment::with('order', 'deliverer')->latest()->limit(25)->get(),
            'payments' => Payment::with('order')->latest()->limit(25)->get(),
            'users' => User::whereIn('role', ['buyer', 'seller', 'deliverer'])->latest()->limit(50)->get(),
            'products' => Product::with(['shop', 'seller'])->latest()->limit(100)->get(),
            'notifications' => NotificationBroadcast::latest()->limit(10)->get(),
            'settings' => [
                'otp_provider' => AppSetting::get('otp_provider', config('services.otp.provider', 'beem')),
                'beem_sender_id' => AppSetting::get('beem_sender_id', config('services.beem.sender_id')),
                'beem_base_url' => AppSetting::get('beem_base_url', config('services.beem.base_url')),
                'infobip_sender_id' => AppSetting::get('infobip_sender_id', config('services.infobip.sender_id')),
                'infobip_base_url' => AppSetting::get('infobip_base_url', config('services.infobip.base_url')),
                'firebase_project_id' => AppSetting::get('firebase_project_id', config('services.firebase.project_id')),
            ],
            'shopCategories' => AppSetting::get('shop_categories', "Electronics\nFashion\nGroceries\nBooks\nArt\nHome\nOther"),
        ]);
    }

    private function authorizeAdmin(): void
    {
        abort_unless(Auth::check() && Auth::user()->role === 'admin', 403);
    }
}
