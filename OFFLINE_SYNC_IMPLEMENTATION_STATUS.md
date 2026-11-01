# Offline Sync Implementation Status

**Project:** Krishi Karobar  
**Branch reviewed:** `phase-1`  
**Reviewed source commit:** `631769d190efe4db377be69cb4e43c10db8fca13`  
**Commit message:** `commit update latest`  
**Review date:** 2026-11-01

## 1. Overall status

<badge>Partial implementation</badge>

Phase 1 contains a substantial Sembast offline foundation and initial integration into selected application workflows. The code includes local persistence, a scoped workspace, a durable sync queue, conflict records, a serialized background sync engine, and registered entity adapters.

**This is not yet a complete full-offline application.** Several screens and services still read from or write directly to Firebase. A successful local save in one workflow does not establish that every feature can operate offline, nor that every queued entity can synchronize correctly in all cases.

## 2. Implemented foundation

| Component | Current implementation |
|---|---|
| Local database | Sembast with platform-specific IO, Web, and stub database factories. |
| Workspace identity | One workspace per environment and business owner: `environment|ownerUserId`. Firebase Auth UID is stored separately. |
| Vehicle scope | Vehicle is a record attribute/filter, not a separate workspace. Access is checked against assigned/owned vehicle IDs and the workspace access profile. |
| Workspace lifecycle | Open/reactivate, lock, owner/auth identity checks, dirty-workspace protection, counts, and clear-only-when-clean behavior. |
| Local records | Scoped repository with transactional record + queue persistence, patch support, and access validation. |
| Queue | Durable create/update/delete references and pending, syncing, failed, blocked, and conflict states. |
| Conflict storage | Separate conflict DAO and retained conflict records; conflicts are not silently discarded during normal sync. |
| Reference snapshots | Dedicated storage for referenced records used by local workflows and sync dependency resolution. |
| Sync engine | Serialized queue processing, connectivity listener, manual retry support, bounded passes, retry/backoff, parent dependency checks, and remote read-back verification. |
| Expense UID | Dedicated offline/online sequence allocation and reconciliation using the Expense-specific format. |

## 3. Registered sync adapters

The standard adapter registry currently includes:

- **Customer** — remote path `customers`.
- **Activity** — remote path `activities`; resolves customer dependency and preserves the existing Activity UID generator.
- **Expense** — remote path `expenses`; resolves its Activity dependency and uses the Expense UID service.
- **Location** — activity/expense location records.
- **Payment** — remote path `payments`; resolves customer and activity references.

Adapter registration means the sync engine knows how to process these entity types. It does **not** prove that all related UI workflows, parent/child transactions, payment allocations, deletion flows, or conflict-resolution paths are fully integrated and production-verified.

## 4. Existing feature integration observed in Phase 1

The reviewed source contains local Sembast persistence calls in selected workflows:

- Activity Monitor saves newly started activity records locally and inserts their sync references.
- Activity Monitor has local persistence calls for activity reset/finalization and related activity/location/customer workflows.
- Recent Activity uses local record patches for selected activity edits/cancellations.
- Activity/customer form workflows contain local persistence calls.
- Expense form saves locally when the offline storage service is available.
- Payment save persists the payment locally and patches affected activity payment totals/due fields locally.

These are **partial integration points**. They must be tested end-to-end with network disabled and restored. Some adjacent operations still call Firebase directly (including background activity/customer/vehicle updates), so the application must not yet be described as universally local-first.

## 5. Identity, access, and UID rules

- Workspace owner identity uses the business `UserModel.id`; Firebase Auth UID is a separate value used for remote authorization.
- Guest or role-less users cannot create local business records.
- Local write roles are defined per entity in `OfflineEntityRoles` and are intended to mirror the Firebase Realtime Database rules.
- Vehicle-scoped users may only use records for vehicles allowed by their workspace access profile.
- Expense UID format is `E` + vehicle code + `-` + last digit of the Nepali year + four-or-more-digit sequence. Example: `EV01-30001`.
- The full Bikram Sambat year is part of the sequence scope; it is not fully represented in the displayed UID.
- Existing Activity UID generation (`SequenceService.generateActivityUid`) and other existing model UID generators must remain unchanged.

Firebase Realtime Database rules remain the authoritative remote security boundary. Local access checks are an additional guard, not a replacement for server rules.

## 6. Known gaps before claiming full offline support

1. **Complete local-first reads:** migrate remaining feature screens, controllers, and services away from mandatory Firebase reads. Ensure each screen can load required data from local records/reference snapshots while disconnected.
2. **Reference-data lifecycle:** reliably seed and refresh users, vehicles, services, customers, expense categories, and other required reference data within the active workspace and access scope.
3. **Write-path audit:** identify every business write path and route it through the local repository/queue before attempting remote synchronization. Remove assumptions that Firebase is immediately available.
4. **Payment integrity:** verify payment allocations, paid/due calculations, discounts, multi-activity payments, parent dependencies, duplicate prevention, and atomic consistency between payment and affected activity records.
5. **Deletion and cancellation:** finish tombstone/delete synchronization. The current sync engine explicitly excludes delete operations from normal processing, so queued deletions remain pending until deletion integration is implemented.
6. **Conflict workflow:** implement and test user-visible conflict inspection and resolution (keep local, keep server, or merge) without dropping unresolved data.
7. **Session and workspace guards:** verify logout, login by another user, session expiry, workspace switching, and vehicle changes when pending, failed, blocked, or conflicting records exist. Do not clear unsynchronized data.
8. **Background lifecycle:** test app pause/resume, process termination, reconnect, repeated retries, and duplicate sync triggers.
9. **Recent Activity consistency:** verify locally saved and edited activities/expenses appear immediately in all relevant lists, summaries, and filters, then remain consistent after sync.
10. **Platform coverage:** verify Android and Web database behavior, persistence, connectivity transitions, and application restart.

## 7. Verification status

This documentation review inspected the source at the commit listed above. It did not execute Flutter/Dart commands or device/browser integration tests.

Do not mark the offline release as complete until the following are run successfully in the development environment:

```bash
dart format .
flutter analyze
flutter test
flutter build apk --flavor dev
flutter build web
```

In addition, perform manual tests with airplane mode/network toggling, app force-stop/restart, multiple users, assigned-vehicle restrictions, pending queue recovery, duplicate prevention, payment due reconciliation, and conflict retention. Confirm the production flavor separately before release.

## 8. Recommended next implementation order

1. Inventory every Firebase read/write in the feature layer and classify it as local-first, remote-only, or reference-data refresh.
2. Complete local repository integration for all required feature reads and writes without changing existing UI or business UID generation.
3. Finish payment/allocation validation and delete/tombstone synchronization.
4. Add reference snapshot refresh and safe session/workspace lifecycle guards.
5. Add conflict inspection/resolution and sync-queue visibility.
6. Run automated checks and Android/Web offline-to-online integration tests.
7. Update this document only from verified test results and the exact commit that was tested.
