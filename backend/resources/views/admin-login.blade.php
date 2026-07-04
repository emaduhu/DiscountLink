<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>DiscountLink Admin Login</title>
    <style>
        body{font-family:Inter,Arial,sans-serif;margin:0;background:#f6f7f9;color:#1f2937;min-height:100vh;display:grid;place-items:center}.panel{width:min(420px,calc(100vw - 32px));background:#fff;border:1px solid #e5e7eb;border-radius:8px;padding:28px;box-sizing:border-box}h1{font-size:24px;margin:0 0 22px}.field{margin-bottom:16px}label{display:block;font-size:13px;font-weight:700;margin-bottom:7px}input{width:100%;box-sizing:border-box;border:1px solid #d1d5db;border-radius:6px;padding:11px 12px;font-size:15px}button{width:100%;border:0;border-radius:6px;background:#111827;color:#fff;font-weight:700;font-size:15px;padding:12px;cursor:pointer}.error{background:#fef2f2;border:1px solid #fecaca;color:#991b1b;border-radius:6px;padding:10px 12px;margin-bottom:16px;font-size:14px}
    </style>
</head>
<body>
<main class="panel">
    <h1>DiscountLink Admin</h1>
    @if($errors->any())
        <div class="error">{{ $errors->first() }}</div>
    @endif
    <form method="post" action="{{ route('admin.authenticate') }}">
        @csrf
        <div class="field">
            <label for="email">Email</label>
            <input id="email" name="email" type="email" value="{{ old('email', config('services.discountlink.admin_email', 'admin@dl.vigourtech.net')) }}" autocomplete="username" required autofocus>
        </div>
        <div class="field">
            <label for="password">Password</label>
            <input id="password" name="password" type="password" autocomplete="current-password" required>
        </div>
        <button type="submit">Sign in</button>
    </form>
</main>
</body>
</html>
