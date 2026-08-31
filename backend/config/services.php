<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

    'google' => [
        'client_id' => env('GOOGLE_CLIENT_ID'),
    ],

    'beem' => [
        'api_key' => env('BEEM_ACCESS_KEY', env('BEEM_API_KEY')),
        'secret_key' => env('BEEM_SECRET_KEY'),
        'sender_id' => env('BEEM_SENDER', env('BEEM_SENDER_ID', 'VIGOURTECH')),
        'base_url' => env('BEEM_SMS_URL', env('BEEM_BASE_URL', 'https://apisms.beem.africa/v1/send')),
        'otp_app_id' => env('BEEM_OTP_APP_ID'),
    ],

    'infobip' => [
        'api_key' => env('INFOBIP_API_KEY'),
        'sender_id' => env('INFOBIP_SENDER_ID', 'DiscountLink'),
        'base_url' => env('INFOBIP_BASE_URL'),
    ],

    'firebase' => [
        'project_id' => env('FIREBASE_PROJECT_ID', 'discount-link-532cc'),
        'credentials' => env('FIREBASE_CREDENTIALS'),
    ],

    'otp' => [
        'provider' => env('SMS_PROVIDER', env('OTP_PROVIDER', 'beem')),
    ],

    'clickpesa' => [
        'client_id' => env('CLICKPESA_CLIENT_ID'),
        'api_key' => env('CLICKPESA_API_KEY'),
        'base_url' => env('CLICKPESA_BASE_URL', 'https://api.clickpesa.com'),
        'webhook_secret' => env('CLICKPESA_WEBHOOK_SECRET'),
        'timeout' => env('CLICKPESA_TIMEOUT', 30),
        'queue' => env('CLICKPESA_QUEUE', 'payments'),
        'queue_tries' => env('CLICKPESA_QUEUE_TRIES', 5),
    ],

    'fcm' => [
        'server_key' => env('FCM_SERVER_KEY'),
    ],

    'discountlink' => [
        'admin_email' => env('DISCOUNTLINK_ADMIN_EMAIL', 'admin@dl.vigourtech.net'),
        'admin_password' => env('DISCOUNTLINK_ADMIN_PASSWORD'),
        'token_days' => env('DISCOUNTLINK_TOKEN_DAYS', 90),
        'show_verification_codes' => env('DISCOUNTLINK_SHOW_VERIFICATION_CODES', false),
        'play_store_url' => env('DISCOUNTLINK_PLAY_STORE_URL', 'https://play.google.com/store/apps/details?id=net.vigourtech.dl'),
        'app_store_url' => env('DISCOUNTLINK_APP_STORE_URL', 'https://apps.apple.com/search?term=Vigour%20Deals'),
    ],

];
