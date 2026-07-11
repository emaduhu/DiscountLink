<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>DiscountLink Admin Login</title>
    <style>
        :root{--bg:#f4f6f8;--panel:#fff;--line:#e4e7ec;--text:#182230;--muted:#667085;--brand:#f97316;--brand-dark:#c2410c}*{box-sizing:border-box}body{font-family:Inter,Arial,sans-serif;margin:0;background:radial-gradient(circle at 20% 10%,#fff2e4 0,#fff2e4 24%,transparent 25%),var(--bg);color:var(--text);min-height:100vh;display:grid;place-items:center;padding:20px}.panel{width:min(430px,100%);background:rgba(255,255,255,.96);border:1px solid var(--line);border-radius:12px;padding:30px;box-shadow:0 18px 45px rgba(16,24,40,.12)}.brand{display:flex;align-items:center;gap:12px;margin-bottom:24px}.mark{display:grid;place-items:center;width:46px;height:46px;border-radius:14px;background:linear-gradient(135deg,#ff8a1f,#f04438);color:#fff;font-weight:900}h1{font-size:24px;margin:0}.sub{color:var(--muted);font-size:13px;margin-top:3px}.field{margin-bottom:16px}label{display:block;font-size:12px;letter-spacing:.04em;text-transform:uppercase;color:var(--muted);font-weight:900;margin-bottom:7px}input{width:100%;border:1px solid #d0d5dd;border-radius:8px;padding:12px 13px;font-size:15px}input:focus{outline:2px solid #fed7aa;border-color:var(--brand)}button{width:100%;border:0;border-radius:8px;background:var(--brand);color:#fff;font-weight:900;font-size:15px;padding:13px;cursor:pointer}button:hover{background:var(--brand-dark)}.error{background:#fef3f2;border:1px solid #fecdca;color:#b42318;border-radius:8px;padding:11px 13px;margin-bottom:16px;font-size:14px;font-weight:800}
    </style>
</head>
<body>
<main class="panel">
    <div class="brand">
        <div class="mark">DL</div>
        <div>
            <h1>DiscountLink Admin</h1>
            <div class="sub">Operations dashboard access</div>
        </div>
    </div>
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
