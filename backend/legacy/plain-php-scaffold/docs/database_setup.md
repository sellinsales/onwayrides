# OnWay Rides Database Setup

This folder contains the first-pass database foundation for the new `onwayrides.com` backend.

## Files

- [01_onwayrides_schema.sql](</d:/projects/onwayrides/backend/database/01_onwayrides_schema.sql>)
- [02_onwayrides_seed.sql](</d:/projects/onwayrides/backend/database/02_onwayrides_seed.sql>)

## What this schema covers

- Firebase-linked users through `users.firebase_uid`
- Rider profiles
- Driver profiles
- Fleet owners with `fleet_code` like `ONW-LHR-0001`
- Vehicle catalog, vehicles, and driver-to-vehicle assignments
- Service types and city-level enable/disable settings
- Pricing rules and commission rules
- Driver and fleet subscription plans
- Unified `bookings` table for app/web orders
- Service-specific tables for:
  - rides
  - rentals
  - school pick & drop
  - food delivery
  - courier
- Offers / negotiated fare
- Booking status history
- Chat/messages
- Tracking points
- Payments
- Wallets
- Payouts
- Driver and vehicle documents
- Complaints
- Ratings and reviews
- Device tokens and notification preferences
- Admin audit logs

## phpMyAdmin import order

1. Create a backup if a database already exists.
2. Open phpMyAdmin.
3. Import [01_onwayrides_schema.sql](</d:/projects/onwayrides/backend/database/01_onwayrides_schema.sql>).
4. Import [02_onwayrides_seed.sql](</d:/projects/onwayrides/backend/database/02_onwayrides_seed.sql>).
5. Confirm that the database `onwayrides_onwayrides` now exists and the seed tables contain data.

## Seeded defaults

The seed file now creates:

- major starter cities
- all initial service types
- city/service availability for the main launch cities
- starter subscription plans
- starter vehicle categories, types, makes, and models
- baseline pricing and commission rules
- one admin user:
  - email: `admin@onwayrides.com`
  - password: `ChangeMe123!`

Change the admin password immediately after first login or replace the hash before importing into production.

## Recommended MySQL settings

- MySQL 8.x preferred
- `utf8mb4` charset
- InnoDB engine
- server timezone stored in UTC

## Firebase mapping

Firebase should be the source of authentication identity.

Recommended mapping:

- Firebase Auth UID -> `users.firebase_uid`
- Firebase email -> `users.email`
- Firebase phone -> `users.phone`
- Firebase display name -> `users.full_name`
- Firebase photo URL -> `users.avatar_url`

Backend login flow should:

1. Verify Firebase ID token on the backend.
2. Find or create the local `users` record by `firebase_uid`.
3. Attach the correct local role:
   - rider
   - driver
   - fleet_owner
   - admin
4. Ensure the matching profile row exists:
   - `rider_profiles`
   - `driver_profiles`
   - `fleet_owners`

## Important design decisions

### 1. One core bookings table

`bookings` is the shared order header for all services.

This keeps:

- rider history simpler
- admin reporting simpler
- payment linkage simpler
- notifications simpler

Then service-specific details go into child tables like:

- `ride_bookings`
- `food_orders`
- `courier_orders`
- `rental_bookings`
- `school_bookings`

### 2. Negotiated fares

Use:

- `bookings.offered_fare`
- `bookings.counter_fare`
- `bookings.price_type`
- `booking_offers`

That is enough for rider offers, driver counters, and acceptance history.

### 3. Fleet support

Fleet support is modeled with:

- `fleet_owners`
- `driver_profiles.fleet_owner_id`
- `vehicles.fleet_owner_id`
- `driver_vehicle_assignments`

This supports:

- independent drivers
- fleet-linked drivers
- fleet-owned vehicles
- assignment history

## What is still not built

The backend now has a working PHP API scaffold, but several production modules still need to be completed.

Still needed:

- verified Firebase ID token login instead of sync-only bootstrap
- admin authentication and admin UI/backend flows
- rider trip history, cancellation, and review endpoints
- driver earnings, wallet, and payout endpoints
- fleet owner CRUD and dashboard endpoints
- document upload and approval flows
- payment gateway integration
- Firebase/Firestore or websocket realtime dispatch integration

## Backend codebase

The backend now includes:

- `public/` for the web entrypoint
- `app/` for controllers and support classes
- `database/` for schema and seeds
- `docs/` for setup instructions
- `storage/uploads/` for writable uploads

For backend application setup and deployment, use [backend_setup.md](</d:/projects/onwayrides/backend/docs/backend_setup.md>).
