# Current Backend, Frontend, Responsive, and Logic Audit Report

Date: 2026-06-08
Project: DhinaDTS Attendance / WorkSync Pro
Workspace: `D:\myproducts\attendance`

## Executive Summary

The application is a Flutter web/mobile/tablet attendance system backed by Firebase Auth, Firestore, Firebase Messaging, and a standalone Node.js FCM relay backend. The current build is healthy: Flutter analysis, Flutter tests, backend syntax checks, and release web build all pass.

The product has strong coverage for attendance, employee/admin role routing, profile management, reports, notifications, messaging, leave handling, salary records, tasks, settings, legal pages, and GitHub Pages web deployment. Recent fixes improved mobile legal/settings/support layouts and made the app bar use the hamburger menu consistently.

Main production risks are not compile errors. They are business-rule enforcement, audit immutability, backend deployment hardening, and end-to-end test depth.

## Attendance Logic Risk Fix Update

The attendance logic recommendations have been implemented in the repository after this audit:

- Added immutable best-effort audit writes for login, out-of-office login attempts, office exit/entry, session close, leave marking, manual attendance decisions, break consideration requests, and backend finalization failures.
- Added a backend finalization endpoint at `/api/attendance/finalize-session` that recalculates attendance from stored office-presence segments instead of trusting client totals.
- Added an optional Flutter API client for backend finalization using `ATTENDANCE_API_BASE_URL` and `ATTENDANCE_API_KEY`.
- Added a dedicated `attendance_consideration_requests` workflow for delayed break consideration, with admin approve/reject processing.
- Added GPS reconciliation on restored/resumed active attendance sessions so missed foreground events can be repaired from the current office-circle state.
- Added ML Kit face metadata capture for liveness review signals.
- Tightened Firestore attendance update rules so employees can only update attendance-flow fields and cannot reassign ownership.

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
- Web hosting deployment through GitHub Pages workflow

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
| Salary backend endpoint | Partial | Flutter has `PayrollApiService`; backend has salary route logic in relay but needs production deployment validation |
| Audit log collection | Partial | Rules define `audit_logs`, but app business actions are not consistently writing immutable audit records |
| Cloud Functions config | Inconsistent | `firebase.json` points functions source to `functions`, but repo backend is under `backend/fcm-relay` |

### Backend Strengths

- Firestore rules are not wide open; most collections are scoped by role or employee ownership.
- The app uses a single Firestore namespace helper, reducing accidental root collection drift.
- Notification architecture is production-oriented: frontend queues messages, backend sends actual FCM.
- Backend syntax checks pass.
- Task import and task assignment backend logic exists.

### Backend Risks

| Severity | Finding | Impact | Recommended Action |
| --- | --- | --- | --- |
| High | `firebase.json` functions source points to `functions`, but backend lives in `backend/fcm-relay` | Firebase deploy may not deploy the actual relay backend | Align deployment config or document relay hosting separately |
| High | Attendance updates can be made by employees for their own attendance docs under broad update rule | Client-side business logic can be bypassed if a user writes directly to Firestore | Restrict employee-updatable attendance fields in rules |
| High | Audit logs exist in rules but are not consistently written by services | Admin decisions, attendance consideration, exports, and profile edits lack full immutable trail | Add centralized audit writer service and call it for critical actions |
| Medium | Backend `.env` exists locally under backend folder | Risk of secrets being committed or copied | Ensure `.env` is ignored and rotate exposed secrets if any were shared |
| Medium | FCM relay production status depends on external deployment | Notifications may queue but not deliver if relay is offline | Add health check monitoring and retry dashboard |
| Medium | Firestore has both root collection rules and `Attendance/main` namespace rules | Duplicate rules increase maintenance risk | Keep canonical namespace and remove/deprecate legacy paths after migration |

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
- GitHub Pages build passes with `/attendance/` base href.

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

- Production reliability depends on the external relay being hosted and monitored.
- No visible admin dashboard for relay failures/retries.
- Firebase pay-as-you-go is still required for some production-grade Firebase backend features depending on final deployment choice.

Recommended:

- Add `/health` check monitoring for relay.
- Add admin notification delivery status screen using `fcm_outbox`.
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
- Salary and payroll APIs need auth token validation if exposed over HTTP.
- Backend relay should verify caller identity and role for all privileged endpoints.
- Secrets handling should be reviewed.
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

## Production Readiness Score

| Area | Score | Notes |
| --- | --- | --- |
| Flutter compile/build health | 9/10 | Clean analysis and release build |
| Web UI | 8/10 | Strong, but needs visual regression tests |
| Tablet UI | 7/10 | Responsive, but not fully tablet-specific |
| Mobile UI | 8/10 | Recent fixes improved key pages |
| Backend relay | 7/10 | Exists and syntax-valid; deployment/monitoring must be confirmed |
| Firestore rules | 7/10 | Good baseline, but employee attendance update scope is broad |
| Attendance business logic | 8/10 | Strong client logic; needs backend enforcement for production |
| Auditability | 5/10 | Audit collection exists, but action logging is incomplete |
| Automated tests | 4/10 | Basic tests only |

Overall readiness: 7/10 for controlled pilot, 5.5/10 for strict production compliance.

## Priority Action Plan

### P0 - Before Production

1. Lock employee attendance Firestore updates to safe fields only.
2. Add backend/server-side final attendance calculation or Cloud Function validation.
3. Confirm production deployment path for `backend/fcm-relay`.
4. Add audit writes for attendance changes, admin approvals, salary generation, exports, profile edits, and bulk notifications.
5. Remove or rotate any secrets that may exist in local `.env` files.

### P1 - Next Sprint

1. Add admin queue for delayed break consideration requests.
2. Add FCM relay delivery status dashboard.
3. Add `.xlsx` formatted export as primary report output.
4. Add Firestore rules tests.
5. Add attendance logic unit tests.

### P2 - Quality Improvements

1. Add visual regression tests for mobile/tablet/web.
2. Add tablet-specific layout pass for admin report/profile screens.
3. Add liveness checks for face attendance.
4. Add background GPS resilience checks.
5. Add analytics-free privacy review for production policies.

## Conclusion

The app is structurally sound and currently builds successfully for web. The frontend now has better mobile behavior, and the backend foundation exists for notifications and task operations. The most important remaining work is hardening business logic at the backend/rules layer and making audit trails complete. For a real production rollout, attendance eligibility and sensitive computed fields should be enforced outside the client, and every admin/business decision should write an immutable audit record.
