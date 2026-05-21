# OnWay Rides

OnWay Rides is a multi-service mobility platform repository containing:

- the public marketing website
- the Laravel backend API
- the mobile app source

## Repository structure

```text
onwayrides/
├── apps/
│   └── mobile/
├── assets/
├── backend/
│   └── Laravel API
├── pages/
├── .github/
│   └── workflows/
├── index.html
├── styles.css
└── app.js
```

## Deployment model

This repository is set up for GitHub Actions deployment over explicit FTPS:

- frontend deploy target: `/public_html/`
- backend deploy target: `/backend/`

That means:

- the static website is uploaded to the main web root
- the Laravel application is uploaded to `/home/onwayrides/backend`
- the backend document root on hosting should point to `/home/onwayrides/backend/public`

## GitHub Actions workflow

Workflow file:

- [deploy.yml](./.github/workflows/deploy.yml)

What it does on push to `main` or manual run:

1. checks out the repo
2. installs production Laravel dependencies
3. generates the backend production `.env` from GitHub Secrets and Variables
4. prepares clean frontend and backend deployment folders
5. uploads both folders to the server over FTPS

## GitHub Environment

Create a GitHub Actions environment named:

- `prd`

Recommended location:

- `Settings > Environments`

Use that environment for production deploy secrets and variables instead of plain repo-level values.

## Required GitHub Secrets

Add these under:

- `Settings > Environments > prd`

### FTP secrets

- `FTP_SERVER`
- `FTP_PORT`
- `FTP_USERNAME`
- `FTP_PASSWORD`

### Laravel secrets

- `LARAVEL_APP_KEY`
- `DB_HOST`
- `DB_PORT`
- `DB_DATABASE`
- `DB_USERNAME`
- `DB_PASSWORD`

## Recommended GitHub Variables

These are non-secret values and should be stored on the same `prd` environment.

- `FTP_FRONTEND_DIR`
- `FTP_BACKEND_DIR`
- `LARAVEL_APP_URL`
- `FRONTEND_URL`
- `ADMIN_URL`
- `SUPPORT_EMAIL`
- `SUPPORT_PHONE`
- `DEFAULT_COUNTRY_CODE`
- `DEFAULT_CURRENCY`
- `CORS_ALLOWED_ORIGINS`

Recommended values:

- `FTP_FRONTEND_DIR=/public_html/`
- `FTP_BACKEND_DIR=/backend/`

## Important backend note

The workflow deliberately creates the production Laravel `.env` during CI from GitHub Secrets. Credentials are not committed to this repository.

## Backend documentation

Start here for backend work:

- [backend/README.md](./backend/README.md)
- [backend/docs/setup.md](./backend/docs/setup.md)
- [backend/docs/database.md](./backend/docs/database.md)
- [backend/docs/deployment-cpanel.md](./backend/docs/deployment-cpanel.md)
- [backend/docs/architecture.md](./backend/docs/architecture.md)

## Before first production deploy

Confirm the hosting side is ready:

1. the domain root serves `public_html`
2. the backend or API subdomain document root points to `/home/onwayrides/backend/public`
3. PHP version is compatible with Laravel
4. required PHP extensions are enabled
5. `storage/` and `bootstrap/cache/` are writable
