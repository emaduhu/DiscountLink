<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Mail;
use Tests\TestCase;

class RegistrationTermsTest extends TestCase
{
    use RefreshDatabase;

    public function test_registration_requires_terms_acceptance(): void
    {
        $response = $this->postJson('/api/auth/register', [
            'role' => 'buyer',
            'full_name' => 'Terms Buyer',
            'email' => 'terms@example.com',
            'phone' => '255700111222',
            'nida_number' => '19900101123456789000',
            'password' => 'password',
            'address' => 'Dar es Salaam',
        ]);

        $response->assertUnprocessable()
            ->assertJsonValidationErrors(['terms_accepted']);
    }

    public function test_registration_stores_terms_acceptance_timestamp(): void
    {
        Mail::fake();
        $response = $this->postJson('/api/auth/register', [
            'role' => 'buyer',
            'full_name' => 'Terms Buyer',
            'email' => 'terms@example.com',
            'phone' => '255700111222',
            'nida_number' => '19900101123456789000',
            'password' => 'password',
            'address' => 'Dar es Salaam',
            'terms_accepted' => true,
        ]);

        $response->assertCreated()
            ->assertJsonPath('user.email', 'terms@example.com');

        $this->assertDatabaseHas('users', ['email' => 'terms@example.com']);
        $this->assertNotNull($response->json('user.terms_accepted_at'));
        $response->assertJsonPath('email_otp_sent', true)
            ->assertJsonPath('credentials_email_sent', true);
    }

    public function test_existing_google_user_must_accept_terms_before_signing_in(): void
    {
        $user = User::factory()->create([
            'email' => 'legacy-google@example.com',
            'terms_accepted_at' => null,
        ]);

        $payload = [
            'google_id_token' => 'dev-google-token:'.$user->email,
            'role' => 'buyer',
        ];

        $this->postJson('/api/auth/google', $payload)
            ->assertUnprocessable()
            ->assertJsonPath('message', 'You must accept the Terms and Conditions before signing in.');

        $this->postJson('/api/auth/google', $payload + ['terms_accepted' => true])
            ->assertOk();

        $this->assertNotNull($user->fresh()->terms_accepted_at);
    }

    public function test_new_social_user_is_told_to_complete_registration_details(): void
    {
        $this->postJson('/api/auth/google', [
            'google_id_token' => 'dev-google-token:NewSocial@example.com',
            'role' => 'buyer',
        ])
            ->assertUnprocessable()
            ->assertJsonPath('code', 'social_registration_required')
            ->assertJsonPath('message', 'Complete registration with your name, phone, NIDA number, and address before using social sign-in.');
    }

    public function test_new_social_user_can_complete_registration_with_same_social_token(): void
    {
        Mail::fake();

        $this->postJson('/api/auth/google', [
            'google_id_token' => 'dev-google-token:NewSocial@example.com',
            'role' => 'buyer',
            'full_name' => 'New Social',
            'phone' => '255700111333',
            'nida_number' => '19900101123456789001',
            'address' => 'Dar es Salaam',
            'terms_accepted' => true,
        ])
            ->assertOk()
            ->assertJsonPath('user.email', 'newsocial@example.com')
            ->assertJsonPath('user.name', 'New Social');

        $this->assertDatabaseHas('users', [
            'email' => 'newsocial@example.com',
            'phone' => '255700111333',
        ]);
    }
}
