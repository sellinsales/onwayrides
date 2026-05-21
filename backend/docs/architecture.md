# Architecture Notes

## Backend framework

- Laravel 12
- PHP 8.3+
- MySQL or MariaDB

## Architectural decision

The backend has been intentionally split into:

- **framework layer**: Laravel application, routing, controllers, config, testing, storage
- **domain schema layer**: SQL snapshots for the full mobility platform schema

This gives a stable path to production while avoiding a rushed full migration rewrite.

## Why Laravel here

This project is not a small CRUD backend. It needs:

- multi-role auth
- document workflows
- bookings and dispatch logic
- payouts and wallet logic
- admin operations
- future queues and scheduled tasks

Laravel is a better long-term fit for that surface area than plain PHP.

## Current implementation boundary

Already in Laravel:

- API entrypoints
- framework bootstrapping
- environment and config structure
- test structure
- storage strategy
- project documentation

Still intentionally SQL-first:

- core business schema
- seed bootstrap data

## Planned next modules

1. Firebase token verification
2. authenticated rider APIs
3. driver availability and offer flow
4. document upload + review
5. fleet owner operations
6. admin management APIs
7. payouts and finance workflows
