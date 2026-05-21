# OnWay Rides Backend Setup

This backend is a lightweight PHP API scaffold intended to get `onwayrides.com` running against the real database now.

## Folder layout

- [public](</d:/projects/onwayrides/backend/public>)
- [app](</d:/projects/onwayrides/backend/app>)
- [database](</d:/projects/onwayrides/backend/database>)
- [docs](</d:/projects/onwayrides/backend/docs>)
- [storage/uploads](</d:/projects/onwayrides/backend/storage/uploads>)

## What is included now

- environment loader
- PDO database bootstrap
- simple router with path parameters
- CORS handling
- JSON API responses
- first usable endpoints:
  - `GET /api/health`
  - `GET /api/bootstrap`
  - `POST /api/auth/sync`
  - `POST /api/bookings/estimate`
  - `POST /api/bookings`
  - `GET /api/bookings/{reference}`
  - `POST /api/drivers/status`
  - `GET /api/drivers/{driverProfileId}/requests`
  - `POST /api/drivers/requests/{bookingId}/respond`

## Required server setup

1. Copy `.env.example` to `.env`
2. Set real values for:
   - database host/user/password
   - Firebase keys
   - mail settings
   - CORS origins
   - maps provider keys
3. Import:
   - [01_onwayrides_schema.sql](</d:/projects/onwayrides/backend/database/01_onwayrides_schema.sql>)
   - [02_onwayrides_seed.sql](</d:/projects/onwayrides/backend/database/02_onwayrides_seed.sql>)
4. Point your domain or API subpath document root to [public](</d:/projects/onwayrides/backend/public>)
5. Ensure Apache rewrite is enabled so `.htaccess` works
6. Ensure PHP has:
   - `pdo`
   - `pdo_mysql`
   - `json`
   - `mbstring`
7. Ensure [storage/uploads](</d:/projects/onwayrides/backend/storage/uploads>) is writable

## Suggested hosting layout

- `public_html/` or web root:
  - serves files from `backend/public`
- app code stays outside direct public access where possible

If using cPanel/shared hosting, the practical approach is:

1. upload the backend folder
2. point the domain/subdomain document root to `backend/public`
3. keep `.env` one level above `public`

## Immediate configuration checklist

- set `APP_URL=https://onwayrides.com`
- set `DB_DATABASE=onwayrides_onwayrides`
- set `DB_USERNAME=onwayrides_onway`
- change `DB_PASSWORD`
- change the seeded admin password after first use
- set `CORS_ALLOWED_ORIGINS`
- set Firebase keys
- set maps key
- set mail credentials

## Current limitations

- Firebase token verification is not implemented yet
- dispatch is polling-style, not realtime
- payments are cash-first
- document upload endpoints are not built yet
- admin panel UI is not built yet
- reject reasons and richer dispatch workflow still need implementation

## Recommended next backend work

1. Replace `auth/sync` with verified Firebase ID token login
2. Add admin login and protected admin endpoints
3. Add document upload and approval endpoints
4. Add rider booking history and trip detail endpoints
5. Add driver earnings and wallet endpoints
6. Add fleet owner CRUD and dashboard endpoints
7. Add realtime dispatch with Firebase/Firestore or websockets
