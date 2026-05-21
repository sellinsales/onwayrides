<?php

namespace Tests\Feature;

// use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ExampleTest extends TestCase
{
    public function test_the_backend_root_returns_service_metadata(): void
    {
        $response = $this->get('/');

        $response
            ->assertOk()
            ->assertJsonFragment([
                'app' => 'OnWay Rides Backend',
                'status' => 'ok',
            ]);
    }
}
