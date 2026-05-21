# cPanel Deployment

## Hosting assumptions

Recommended minimum hosting capabilities:

- cPanel
- MultiPHP Manager
- Composer support
- PHP `8.3+`
- MySQL or MariaDB
- ability to point a domain or subdomain to `backend/public`
- cron jobs

## Deployment steps

1. Upload the backend folder
2. Run `composer install --no-dev --optimize-autoloader`
3. Copy `.env.example` to `.env`
4. Fill production environment values
5. Point the document root to `backend/public`
6. Import:
   - `database/sql/01_onwayrides_schema.sql`
   - `database/sql/02_onwayrides_seed.sql`
7. Ensure these paths are writable:
   - `storage/`
   - `bootstrap/cache/`
8. Run:

   ```bash
   php artisan storage:link
   ```

## GitHub Actions deployment

This repository now includes a GitHub Actions workflow at:

- `/.github/workflows/deploy.yml`

The workflow is designed to:

- upload the static frontend to `public_html`
- upload the Laravel backend to `/backend`
- generate the production Laravel `.env` from GitHub Secrets during CI

For production use, configure FTP and Laravel secrets in the GitHub repository instead of storing them in version control.

## Recommended cPanel checks

- `Terminal` or `SSH Access`
- `Cron Jobs`
- `MultiPHP Manager`
- document root control for the domain or subdomain

## Production recommendations

- set `APP_ENV=production`
- set `APP_DEBUG=false`
- use HTTPS only
- restrict public access to `public/` only
- keep `.env` outside accidental public exposure
- back up both the database and uploaded files
