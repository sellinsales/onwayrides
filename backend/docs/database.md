# Database Strategy

## Current approach

The backend is currently **Laravel application layer + SQL-first domain schema**.

That means the business tables are defined in SQL snapshots instead of fully rewritten Laravel migrations right now.

## Canonical SQL files

- `database/sql/01_onwayrides_schema.sql`
- `database/sql/02_onwayrides_seed.sql`

Import order matters:

1. schema
2. seed

## Why this approach

- the platform already has a large production-style schema
- keeping the SQL snapshot avoids unnecessary churn during the Laravel move
- Laravel can now be used for API structure, auth, storage, validation, and jobs immediately
- table-by-table migration conversion can happen later under control

## Laravel migration policy right now

- keep framework-support migrations only when needed
- avoid duplicate migrations for tables already defined in the SQL schema
- add future business migrations only for incremental changes once the base schema is stable

## Seed note

The SQL seed provides starter platform data such as:

- system settings
- cities
- service types
- subscription plans
- vehicle catalog basics
- pricing rules
- commission rules
- initial admin user

## Admin bootstrap account

The starter SQL seed includes:

- `admin@onwayrides.com`
- password: `ChangeMe123!`

Change that password immediately after first use.
