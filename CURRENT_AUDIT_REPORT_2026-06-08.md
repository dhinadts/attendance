# Current Backend, Frontend, Responsive, and Logic Audit Report

Date: 2026-06-08
Project: DhinaDTS Attendance / WorkSync Pro
Workspace: `D:\myproducts\attendance`

## Executive Summary

The application is a Flutter web/mobile/tablet attendance system backed by Firebase Auth, Firestore, Firebase Messaging, and a standalone Node.js FCM relay backend. The current build is healthy: Flutter analysis, Flutter tests, backend syntax checks, and release web build all pass.

The product has strong coverage for attendance, employee/admin role routing, profile management, reports, notifications, messaging, leave handling, salary records, tasks, settings, legal pages, and EC2/Nginx web deployment. Recent fixes improved mobile legal/settings/support layouts and made the app bar use the hamburger menu consistently.

Main production risks are not compile errors. They are business-rule enforcement, audit immutability, backend deployment hardening, and end-to-end test depth.

## Attendance Logic Risk Fix Update

The attendance logic recommendations have been implemented in the repository after this audit:

- Added immutable best-effort audit writes for login, out-of-office login attempts, office exit/entry, session close, leave marking, manual attendance decisions, break consideration requests, and backend finalization failures.
- Added a backend finalization endpoint published through `/p1/attendance/finalize-session` that recalculates attendance from stored office-presence segments instead of trusting client totals.
- Added an optional Flutter API client for backend finalization using `ATTENDANCE_API_BASE_URL` and `ATTENDANCE_API_KEY`.
- Added a dedicated `attendance_consideration_requests` workflow for delayed break consideration, with admin approve/reject processing.
- Added GPS reconciliation on restored/resumed active attendance sessions so missed foreground events can be repaired from the current office-circle state.
- Added ML Kit face metadata capture for liveness review signals.
- Tightened Firestore attendance update rules so employees can only update attendance-flow fields and cannot reassign ownership.
- Hardened backend deployment and operations: removed invalid Firebase Functions config, required backend API key by default, added relay health/status/outbox retry endpoints, and documented EC2 deployment monitoring.

Production note: backend finalization becomes authoritative only after the relay backend is deployed and Flutter is built with a valid `ATTENDANCE_API_KEY`. Firestore rules are updated in source and should be deployed to Firebase before treating the restrictions as active in production.

## Verification Results

| Area | Command | Result |
| --- | --- | --- |
| Flutter static analysis | `flutter analyze` | Passed: no issues found |
| Flutter widget tests | `flutter test` | Passed: 3 tests |
| Backend syntax | `npm --prefix backend run check` | Passed |
| Release web build | `flutter build web --release --base-href /attendance/` | Passed |

## Technology Stack

### Frontend

- Flutter 3 / Dart
- `go_router` for routing
- Firebase Auth
- Cloud Firestore
- Firebase Messaging
- Local notifications
- Camera and ML Kit face detection
- Geolocator
- File picker and Excel/CSV export
- Responsive shell for web and mobile

### Backend

- Node.js Express backend in `backend/fcm-relay`
- Firebase Admin SDK
- FCM relay for push delivery
- Task APIs and task import helpers
- Demo user seeding script

### Data and Hosting

- Firestore namespace: `Attendance/main/{collection}`
- Firestore rules: `firestore.rules`
- Storage rules: `storage.rules`
- Web hosting deployment through EC2/Nginx at `https://workforce.dhinadts.com/`

## Backend Audit

### Implemented Backend Capabilities

| Capability | Status | Notes |
| --- | --- | --- |
| Firebase Auth | Implemented | Used for employee/admin login and route guards |
| Firestore namespace helper | Implemented | `AppFirestore` routes data to `Attendance/main` |
| Firestore security rules | Implemented | Role-based rules exist for users, profiles, attendance, leave, salary, tasks, notifications |
| FCM relay backend | Implemented | Node.js backend can process notification delivery outside Firebase Spark client limits |
| Notification outbox | Implemented | App writes to `fcm_outbox`; backend relay can process queued messages |
| Task backend | Implemented | Backend task model/service/controller/routes exist |
| Salary backend endpoint | Implemented | Flutter has `PayrollApiService`; relay has salary upload/read/generation endpoints guarded by API key |
| Audit log collection | Implemented | Central audit writer and critical attendance/admin action logs have been added |
| Cloud Functions config | Fixed | `firebase.json` no longer points to a non-existent `functions` folder; relay deployment is documented separately |

### Backend Strengths

- Firestore rules are not wide open; most collections are scoped by role or employee ownership.
- The app uses a single Firestore namespace helper, reducing accidental root collection drift.
- Notification architecture is production-oriented: frontend queues messages, backend sends actual FCM.
- Backend syntax checks pass.
- Task import and task assignment backend logic exists.

### Backend Risks

| Severity | Finding | Impact | Recommended Action |
| --- | --- | --- | --- |
| Fixed | `firebase.json` functions source pointed to `functions`, but backend lives in `backend/fcm-relay` | Firebase deploy could target the wrong backend path | Removed invalid Functions config and documented standalone relay hosting |
| Fixed | Attendance updates could be made by employees for their own attendance docs under broad update rule | Client-side business logic could be bypassed if a user wrote directly to Firestore | Restricted employee-updatable attendance fields in rules |
| Fixed | Audit logs existed in rules but were not consistently written by services | Admin decisions and attendance consideration lacked full immutable trail | Added centralized audit writer service and critical attendance/admin action logs |
| Controlled | Backend `.env` exists locally under backend folder | Risk of secrets being committed or copied | `.env` is ignored, `.env.example` is safe, and production docs require hosting-provider env vars |
| Fixed | FCM relay production status depended on external deployment with limited visibility | Notifications could queue but not deliver if relay is offline | Added JSON `/health`, API-key-protected `/p1/relay/status`, outbox listing, retry endpoint, and EC2 deployment script |
| Controlled | Firestore has both root collection rules and `Attendance/main` namespace rules | Duplicate rules increase maintenance risk | Canonical namespace remains `Attendance/main`; root rules are retained only for migration/backward compatibility |

## Frontend Audit

### Current Screen Coverage

| Module | Employee | Admin | Status |
| --- | --- | --- | --- |
| Login/signup | Yes | Yes | Implemented |
| Dashboard | Yes | Yes | Implemented |
| Face attendance | Yes | Admin via mark attendance | Implemented |
| Attendance details | Yes | Yes | Implemented |
| Attendance log | Yes | Admin logs | Implemented |
| Profile | Yes | Yes | Implemented |
| Settings | Yes | Yes | Implemented |
| Notifications | Yes | Yes | Implemented |
| Messages | Yes | Yes | Implemented |
| Leave requests | Employee request, admin approval | Yes | Implemented |
| Salary/payroll | Employee view, admin manage | Yes | Implemented |
| Tasks | Employee update, admin assign | Yes | Implemented |
| Exit request | Employee request, admin review | Yes | Implemented |
| CSV/export reports | Admin | Yes | Implemented |
| Privacy/Terms/Support | Public/mobile-friendly | Public/mobile-friendly | Implemented |

### Web View

Status: Good

- Uses desktop/admin web shell for large desktop and web.
- Side menu supports expanded/collapsed layout.
- Admin screens have dense SaaS-style layout.
- Export/report workflows are available.
- EC2/Nginx deployment script builds the app with root base href for `https://workforce.dhinadts.com/`.

Risks:

- Browser visual regression tests are not automated.
- Some pages are complex and may still need manual QA at 1366px, 1440px, and wide desktop.
- Route-level auth is client-side; Firestore rules must remain the source of truth.

### Tablet View

Status: Partial to Good

- Flutter responsive layouts generally adapt with `LayoutBuilder`, wraps, grids, and shell breakpoints.
- Tablet-specific UX is not consistently designed as a first-class target.
- Some screens use mobile or desktop patterns depending on width rather than dedicated tablet layouts.

Recommended tablet checks:

- 768x1024 portrait
- 1024x768 landscape
- 820x1180 tablet portrait
- Verify side menu behavior, app bar actions, cards, table/list density, export report filters, and profile edit forms.

### Mobile View

Status: Improved and mostly usable

Recent fixes:

- Settings cards are compact on mobile.
- Privacy, Terms, and Support no longer force desktop shell on mobile.
- Support quick cards use responsive grid and no longer overflow.
- App bar now uses hamburger menu instead of back arrow.
- Mobile overflow widget test added for Support, Privacy, and Terms.

Remaining mobile risks:

- Camera/face attendance requires device-level testing.
- Geolocation behavior requires real device testing.
- App drawer should be manually checked after navigation to public pages.
- Long employee names, team names, and role labels should be tested with real data.

## Attendance Logic Audit

### Current Implemented Logic

| Rule | Status | Location |
| --- | --- | --- |
| Office location fixed at `11.3966658, 77.8880424` | Implemented | `AttendanceSessionService` |
| Office radius 50 meters | Implemented | `AttendanceSessionService` |
| 7 hours / 420 office minutes for attendance eligibility | Implemented | `AttendanceSessionService` |
| Out-of-office login attempt is logged | Implemented | `createLogin` |
| Office time starts only inside office circle | Implemented | `createLogin`, segments |
| Leaving office starts break segment | Implemented | `recordOfficeExit` |
| Re-entry creates new office segment | Implemented | `recordOfficeEntry` |
| Break over 30 minutes requires reason | Implemented | `recordOfficeEntry`, Attendance Log UI |
| Multiple breaks per day | Implemented through segments | `segments` array |
| Final attendance uses office minutes, not total elapsed minutes | Implemented | `closeSession` |

### Attendance Logic Risks

| Severity | Finding | Impact | Recommended Action |
| --- | --- | --- | --- |
| High | Location/geofence enforcement is client-driven | A rooted/device-debug user may bypass client logic | Move final attendance calculation to backend or Cloud Function |
| High | Employee can update own attendance document broadly in rules | User may tamper with status/minutes if Firestore API is abused | Restrict allowed employee fields and require admin/backend for computed fields |
| Medium | GPS stream can pause in background or due to permission/battery | Break detection may miss exit/re-entry events | Add periodic resume checks and server-side anomaly flags |
| Medium | Face recognition is local ML Kit landmark-based, not server biometric verification | Spoofing risk depends on camera/live checks | Add liveness checks or stronger verification if high-security |
| Medium | Delayed break consideration has request capture but admin review flow is not fully separated | Admin decision trail may be incomplete | Add dedicated `attendance_consideration_requests` collection and admin queue |

## Notification Logic Audit

### Current State

- Frontend supports team messages, employee/team notification views, inbox/read tracking, and FCM token registration.
- Bulk messages are queued for backend relay using `fcm_outbox`.
- Backend relay exists to send FCM with Firebase Admin SDK.

Risks:

- Production reliability depends on the external relay being hosted with required environment variables.
- Frontend admin dashboard for relay failures/retries is still pending, but backend status/retry APIs now exist.
- Firebase pay-as-you-go is still required for some production-grade Firebase backend features depending on final deployment choice.

Recommended:

- Configure `/health` monitoring for relay in the hosting provider.
- Add admin notification delivery status screen using `/p1/relay/status`, `/p1/fcm-outbox`, and `fcm_outbox`.
- Keep bulk sends backend-only.

## Export and Reporting Logic Audit

### Implemented

- Admin export report screen exists.
- CSV export utilities include web and IO implementations.
- Required columns were implemented earlier:
  - Date
  - Team
  - Employee Role
  - Employee Name
  - Employee ID/Code
  - Attendance
- Custom date filter workflow exists in admin report screen.

Risks:

- CSV is user-confusing compared with formatted Excel.
- Excel package exists in dependencies, but current export path should be verified for `.xlsx` output if business users expect Excel formatting.

Recommended:

- Prefer `.xlsx` export with bold headers, date filters, sheet title, frozen header row, and status color coding.
- Keep CSV as secondary/plain data export.

## Role and Permission Audit

### Current Roles

- Employee
- Partial Admin
- Admin

### Current Role Rules

- Admin-like users can access admin areas.
- Partial admin access is constrained for leave and salary based on permission flags.
- Full admin can assign roles and create privileged accounts.

Risks:

- Partial admin task permissions are broad because partial admin is treated as admin-like for tasks.
- Firestore rules and client route guards must stay aligned.

Recommended:

- Add explicit permission flags:
  - `canManageTasks`
  - `canExportReports`
  - `canSendBulkNotifications`
  - `canManageEmployees`
- Reflect these in Firestore rules and route redirects.

## Security Audit

### Good

- Firestore default catch-all denies access.
- Most sensitive collections require signed-in user and role/ownership checks.
- Admin-only areas are guarded in router and rules.
- FCM token writes are scoped to current user.
- Audit collection is append-only by rule.

### Needs Improvement

- Computed attendance fields should not be writable by employees.
- Salary and payroll APIs are guarded by backend API key; production should rotate and store the key only in the EC2 env file or a managed secret store.
- Backend relay verifies privileged endpoint callers with `BACKEND_API_KEY` and fails closed unless local unauthenticated mode is explicitly enabled.
- Secrets handling should be reviewed before production deployment.
- Export actions should be audited.

## Data Model Audit

### Good

- Canonical namespace `Attendance/main` is scalable.
- Flat collections with `employeeId`, `teamId`, `date`, `monthKey` are query-friendly.
- Attendance segments allow multiple office/break cycles per day.

### Needs Improvement

- `attendance` and `attendance_records` coexist; canonical use should be clarified.
- Consideration requests should become their own collection for admin workflow.
- Audit logs should include:
  - actor UID
  - actor role
  - entity type
  - entity ID
  - before/after diff where safe
  - timestamp
  - device/IP metadata where available

## Test Coverage Audit

Current tests:

- Primary action button tap
- Status chip render
- Mobile Support/Privacy/Terms overflow render test

Coverage gap:

- No integration tests for attendance flow.
- No Firestore rules tests.
- No backend API tests.
- No role-permission tests.
- No export file content tests.
- No notification relay tests.

Recommended test plan:

1. Firestore rules tests for employee/admin/partial admin.
2. Attendance service unit tests for:
   - outside login
   - office entry
   - break under 30 minutes
   - break over 30 minutes
   - 7-hour eligibility
3. Export tests for required headers and date filtering.
4. Backend relay tests for validation and delivery queue handling.
5. Responsive widget tests for settings, profile, attendance log, export report, and admin dashboard.

Required manual device QA:

- Camera/face attendance requires device-level testing with camera permission allow/deny, lighting variation, multiple-face rejection, and failed/spoof attempts.
- Geolocation behavior requires real device testing for inside/outside 50 meter office circle, multiple daily breaks, 30 minute return grace, and app background/resume reconciliation.
- App drawer behavior should be manually checked after navigation to Privacy Policy, Terms of Service, Support, and other public pages.
- Long employee names, team names, role labels, and employee codes should be tested with real data on mobile, tablet, and desktop widths.
- Detailed manual steps are documented in `PRODUCTION_QA_CHECKLIST_2026-06-08.md`.

## Production Readiness Score

| Area | Score | Notes |
| --- | --- | --- |
| Flutter compile/build health | 9/10 | Clean analysis and release build |
| Web UI | 8/10 | Strong, but needs visual regression tests |
| Tablet UI | 7/10 | Responsive, but not fully tablet-specific |
| Mobile UI | 8/10 | Recent fixes improved key pages |
| Backend relay | 8/10 | Syntax-valid, API-key guarded, health/status/retry endpoints added; production host still must be configured |
| Firestore rules | 8/10 | Employee attendance update scope is restricted in source; rules still need Firebase deployment |
| Attendance business logic | 8.5/10 | Backend finalization hook and segment calculation added; real device GPS validation still required |
| Auditability | 7/10 | Critical attendance/admin action logging added; exports/profile/salary can be expanded further |
| Automated tests | 4/10 | Basic tests only |

Overall readiness: 8/10 for controlled pilot, 6.5/10 for strict production compliance pending Firebase rules deployment, relay environment setup, and real-device QA evidence.

## Priority Action Plan

### P0 - Before Production

1. Deploy updated Firestore rules from this repository.
2. Deploy `backend/fcm-relay` with `BACKEND_API_KEY`, Firebase service account env vars, and `/health` monitoring.
3. Run `deploy/ec2/make-workforceops-live.sh` with backend env values before relying on server-side attendance finalization.
4. Execute `PRODUCTION_QA_CHECKLIST_2026-06-08.md` on real mobile/tablet devices.
5. Rotate any secrets that may have been shared outside hosting-provider environment settings.

### P1 - Next Sprint

1. Add Firestore rules tests.
2. Add a frontend admin relay delivery dashboard backed by `/p1/relay/status` and `/p1/fcm-outbox`.
3. Add `.xlsx` formatted export as primary report output.
4. Add Firestore rules tests.
5. Add attendance logic unit tests.

### P2 - Quality Improvements

1. Add visual regression tests for mobile/tablet/web.
2. Add tablet-specific layout pass for admin report/profile screens.
3. Expand liveness checks for face attendance after real-device QA.
4. Expand background GPS resilience checks after real-device QA.
5. Add analytics-free privacy review for production policies.

## Conclusion

The app is structurally sound and currently builds successfully for web. The frontend now has better mobile behavior, and the backend foundation exists for notifications, task operations, salary APIs, attendance finalization, relay monitoring, and API-key guarded operations. The most important remaining work is production deployment and evidence: deploy Firestore rules, configure the relay environment, build the app with attendance backend secrets, and complete real-device QA for camera, GPS, navigation, and long real data.
