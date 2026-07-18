<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
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
    }
}
