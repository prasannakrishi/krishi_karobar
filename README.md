# Krishi Karobar

Krishi Karobar is a Flutter application for managing agricultural-service operations for Prasanna Aadhunik Krishi Kendra. It brings vehicle and service management, live activity monitoring, customer records, expenses, payments, billing, and financial summaries into one application.

> **Development status:** The `phase-1` branch contains the first integrated offline-storage and synchronization foundation. It is not yet a complete full-offline release. See [Offline Sync Implementation Status](OFFLINE_SYNC_IMPLEMENTATION_STATUS.md) for implemented components, integration gaps, and verification requirements.

## Core application features

### Operations
- Vehicle, service, driver, and supervisor management.
- Activity monitoring with start, pause/resume, stop, reset/cancellation, and activity details.
- Activity GPS capture and manual location tagging.
- Customer search/autocomplete and customer details.
- Recent Activity and expense records.

### Finance
- Activity rates, discounts, paid/due amounts, and payment allocations.
- Payment history and bill/payment-slip views.
- Expense records and expense details.
- Dashboard summaries and daily, weekly, monthly (Bikram Sambat), and yearly reporting.

### Access and security
- Centralized role/permission checks through `AuthorizationService`.
- User and vehicle record-scope checks.
- Firebase Realtime Database security rules in [firebase_rtdb.rules.json](firebase_rtdb.rules.json). Client-side permission checks improve the UI and application workflow; Firebase rules remain the server-side security boundary.

## Technology stack

| Area | Technology |
|---|---|
| UI and application | Flutter, Dart |
| State management and navigation | GetX |
| Remote authentication and data | Firebase Authentication, Firebase Realtime Database |
| Local offline database | Sembast (`sembast`, `sembast_web`) |
| Connectivity | `connectivity_plus` |
| Local preferences/session support | GetStorage, SharedPreferences |
| Identifiers | UUID and existing application sequence services |
| Date handling | Nepali Utils, Nepali Date Picker, Intl |

## Offline architecture (Phase 1)

The offline foundation uses a local Sembast database and a scoped workspace:

- A workspace is identified by the build environment and business owner: `environment|ownerUserId`. Firebase Auth UID is retained separately for remote authorization.
- Vehicle selection is a record-level filter, not a separate local workspace. Vehicle access is checked against the workspace access profile and assigned/owned vehicles.
- Local records and their sync-queue references are persisted together. Queue entries track create/update/delete operations and statuses such as pending, syncing, failed, blocked, and conflict.
- A serialized sync engine listens for connectivity changes, retries eligible work, checks parent dependencies, verifies remote writes by reading records back, and retains conflicts for review.
- Registered sync adapters currently cover customers, activities, expenses, activity/expense locations, and payments.
- Expense IDs use the dedicated vehicle/year/sequence convention (for example, `EV01-30001`). Existing Activity and other model UID generators are preserved.

**Important limitations:** Not every screen or service has been migrated to local-first reads and writes. Some workflows still call Firebase directly; reference-data seeding, payment/due reconciliation, deletion handling, conflict resolution UX, and complete logout/session integration require further work and testing. Offline support should therefore be treated as partial until the remaining migration and device tests are complete.

## Project structure

```text
lib/
├── common/       # Shared UI components
├── features/     # Authentication, activity, dashboard, payment, expense, settings
├── models/       # Business and user models
├── offline/
│   ├── core/     # Workspace scope, access policy, schema, database factories
│   ├── data/     # Local records, queue, conflicts, reference snapshots
│   ├── sync/     # Sync engine, gateway, adapters, record comparison
│   └── uid/      # Offline Expense UID allocation and reconciliation
├── services/     # Firebase, cache, session, authorization, sequence services
├── utils/        # Constants, helpers, themes, validation
└── widgets/      # Reusable application widgets
```

## Getting started

### Requirements
- Flutter SDK compatible with the Dart constraint in `pubspec.yaml`.
- Android Studio or another Flutter-compatible IDE.
- A configured Firebase project and the matching platform configuration files.

### Run locally

```bash
git clone https://github.com/prasannakrishi/krishi_karobar.git
cd krishi_karobar
flutter pub get
flutter run
```

The Android project contains separate `dev` and `prod` source configurations. Use the matching Firebase configuration and build flavor for the intended environment.

Before submitting changes, run:

```bash
dart format .
flutter analyze
flutter test
```

Also build and manually verify the Android and Web targets when changes affect platform-specific database or connectivity behavior.

## Documentation

- [Offline Sync Implementation Status](OFFLINE_SYNC_IMPLEMENTATION_STATUS.md) — current implementation, known gaps, and next milestones.
- [Firebase Realtime Database rules](firebase_rtdb.rules.json) — server-side access policy.

## License

This application is maintained for Prasanna Aadhunik Krishi Kendra. It is not intended for public package distribution.
