# Backend Setup

## Goal

Set up the Laravel backend locally or on hosting while continuing to use the production-first SQL schema.

## Requirements

- PHP `8.3+`
- Composer `2+`
- MySQL `8+` or MariaDB equivalent
- writable `storage/` and `bootstrap/cache/`

## Install

1. Run:

   ```bash
   composer install
   ```

2. Create `.env` from `.env.example`

3. Generate the Laravel key:

   ```bash
   php artisan key:generate
   ```

4. Update these environment values:

   - `APP_URL`
   - `DB_HOST`
   - `DB_PORT`
   - `DB_DATABASE`
   - `DB_USERNAME`
   - `DB_PASSWORD`
   - `FRONTEND_URL`
   - `ADMIN_URL`
   - `SUPPORT_EMAIL`
   - `SUPPORT_PHONE`

5. Import:

   - `database/sql/01_onwayrides_schema.sql`
   - `database/sql/02_onwayrides_seed.sql`

6. Create the public storage symlink:

   ```bash
   php artisan storage:link
   ```

7. Start the app:

   ```bash
   php artisan serve
   ```

## Initial verification

Check:

- `/`
- `/up`
- `/api/health`
- `/api/bootstrap`

## Important note

Do not run old default Laravel domain migrations against the production database. The platform domain schema already exists in `database/sql/`.
