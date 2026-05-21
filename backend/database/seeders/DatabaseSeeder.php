<?php

namespace Database\Seeders;

use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        // Business seed data is currently maintained in database/sql/02_onwayrides_seed.sql
        // while the project transitions from a SQL-first bootstrap to Laravel migrations.
    }
}
