<?php

namespace App\Http\Controllers;

use App\Models\DeliveryAssignment;
use App\Models\Order;
use App\Models\Payment;
use App\Models\Product;
use App\Models\Shop;
use App\Models\User;
use Illuminate\Contracts\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Str;
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
        ]);
    }
}
