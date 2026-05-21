# OnWay Rides Backend

Laravel backend for the `OnWay Rides` platform. This codebase is now the clean, long-term backend foundation for the rider, driver, fleet-owner, merchant, and admin systems.

## What changed

The backend was moved from a hand-written plain PHP scaffold to Laravel so the project has a maintainable structure for:

- API routing and middleware
- validation and request lifecycle management
- authentication and authorization
- queued jobs and scheduled tasks
- file storage for private driver and vehicle documents
- scalable service modules as the platform grows

The previous plain PHP scaffold was not deleted. It was archived to:

- `legacy/plain-php-scaffold/`

## Current backend direction

This repository is intentionally in a **Laravel app + SQL-first domain schema** phase.

That means:

- Laravel is now the application framework
- the business database currently lives in `database/sql/`
- the platform schema is imported from SQL first
- per-table Laravel migrations for the business domain can be introduced gradually later

This is deliberate. It keeps the existing production-oriented schema usable now while moving the application layer to a professional framework.

## Current API surface

Implemented as clean Laravel routes:

- `GET /`
- `GET /up`
- `GET /api/health`
- `GET /api/bootstrap`

These are framework-safe starter endpoints for environment verification and platform bootstrap metadata.

## Project structure

```text
backend/
├── app/
│   ├── Http/Controllers/Api/
│   └── Models/
├── bootstrap/
├── config/
├── database/
│   ├── migrations/
│   ├── seeders/
│   └── sql/
├── docs/
├── legacy/
│   └── plain-php-scaffold/
├── public/
├── routes/
├── storage/
├── tests/
├── .env.example
├── artisan
├── composer.json
└── README.md
```

## Local setup

1. Install dependencies:

   ```bash
   composer install
   ```

2. Create environment file:

   ```bash
   copy .env.example .env
   ```

3. Generate the application key:

   ```bash
   php artisan key:generate
   ```

4. Configure database credentials in `.env`

5. Import SQL files in this order:

   - `database/sql/01_onwayrides_schema.sql`
   - `database/sql/02_onwayrides_seed.sql`

6. Create the storage symlink:

   ```bash
   php artisan storage:link
   ```

7. Start local development:

   ```bash
   php artisan serve
   ```

## Database strategy

The domain schema is currently maintained as SQL snapshots:

- `database/sql/01_onwayrides_schema.sql`
- `database/sql/02_onwayrides_seed.sql`

Laravel framework migrations are currently reserved for framework-support tables and future incremental migration work. The default Laravel `users` migration was removed so it does not conflict with the real `users` table already defined in the platform schema.

## File storage strategy

Server-hosted file storage is the initial deployment model.

Private storage is the default for:

- driver documents
- vehicle documents
- complaint attachments
- profile photos

Configured disks live in `config/filesystems.php`.

## Testing and formatting

Run tests:

```bash
php artisan test
```

Run formatting:

```bash
vendor/bin/pint
```

Check formatting:

```bash
vendor/bin/pint --test
```

## cPanel / shared hosting notes

This backend is designed to be deployable on cPanel hosting that supports:

- PHP 8.3+
- Composer
- document root control to `public/`
- writable `storage/` and `bootstrap/cache/`
- MySQL or MariaDB
- cron jobs for later scheduled tasks

See:

- [docs/setup.md](./docs/setup.md)
- [docs/database.md](./docs/database.md)
- [docs/deployment-cpanel.md](./docs/deployment-cpanel.md)
- [docs/architecture.md](./docs/architecture.md)

## Immediate next implementation phases

1. Firebase ID token verification in Laravel
2. auth guards, roles, and protected API middleware
3. rider booking creation and history modules
4. driver availability, offers, and dispatch modules
5. document upload and approval flows
6. payments, wallets, commissions, and payouts
7. fleet owner and admin APIs

## Archived scaffold

The original lightweight backend remains available for reference only:

- `legacy/plain-php-scaffold/`

It should not be extended further unless there is a very specific migration reference need.
