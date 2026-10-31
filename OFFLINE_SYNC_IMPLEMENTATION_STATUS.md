# Krishi Karobar v8.4.4 — Offline Sync implementation notes

## Changes in this package

- Added `lib/offline/sync/sync_engine.dart`: serialized queue worker, Firebase connection listener, retries/backoff, create-if-absent idempotency, server read-back verification, parent checks, UID finalization through existing adapters, and conflict retention.
- Wired a lazy `SyncEngine` into `OfflineStorage`; added `activateWorkspace(scope, ownerPhone)`, `syncNow()`, and `retryFailedSync()`.
- Local record saves now trigger background sync asynchronously when the engine is active; UI waits only for the local Sembast transaction.
- Connected the dashboard's selected-vehicle state to workspace activation without changing its widgets/layout.
- Corrected the activity monitor's offline repository scope to use Firebase Auth UID (not business user ID) and the canonical activity entity key.
- Kept existing UI widgets, business models, `SequenceService.generateActivityUid` implementation, and existing model UID generation unchanged.

## Verification status — important

This is an **offline-sync foundation/integration milestone, not a complete full-offline release**. This environment has no Dart/Flutter SDK, so `flutter analyze`, Android build, Web build, and device tests could not be run.

The current app still has feature screens and services that read/write Firebase directly. Those paths have not all been migrated to local-first repositories, reference data is not yet comprehensively seeded into Sembast, and payments do not yet have a dedicated sync adapter. Therefore, do not treat this ZIP as proof that every screen can run offline or as production-ready.

## Required next stage

Migrate each existing feature's reads and writes to local repositories while keeping the current UI: customers, activities, activity locations, expenses, payments, users, vehicles, services, categories, and settings/reference data. Add payment due/allocation validation, scoped reference snapshots, safe logout/vehicle-switch guards, then run Android + Web integration tests before release.
