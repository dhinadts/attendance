# Attendance Application Audit

Date: 2026-06-02  
Workspace: `D:\myproducts\attendance`  
Audited areas: Flutter app, Firebase Auth/Firestore/Storage rules, FCM notification flow, Node.js backend relay, routing/roles, payroll, attendance, and deployment configuration.

## Executive Summary

The application has a solid Firebase-based foundation and the current Flutter code passes static analysis and the existing widget tests. The most important recent role work is present: full admin-only user creation, organization-role mapping, partial admin permissions, and route guards for leave/salary pages.

The main production risks are security and consistency issues around Firestore/Storage rules, backend API hardening, role enforcement gaps inside UI screens, and the current client-heavy attendance/payroll model. The app is usable, but before production deployment it needs stricter rule validation, backend authentication, more tests, and cleanup of root-vs-`Attendance/main` data references.

## Verification Run

These checks were run during the audit:

```text
flutter analyze
Result: passed, no issues found

flutter test
Result: passed, 2 tests passed

npm --prefix backend\fcm-relay run check
Result: passed, Node syntax check passed
```

Existing tests are very small and only cover shared widgets, so passing tests should not be treated as functional coverage for auth, attendance, notifications, payroll, or Firebase rules.

## Architecture Snapshot

### Frontend

- Flutter app targeting Android, iOS, Web, Windows, Linux, and macOS.
- Firebase SDKs:
  - Firebase Auth
  - Cloud Firestore
  - Firebase Messaging
- Main router: `lib/router/app_router.dart`
- Main role service: `lib/services/auth_role_service.dart`
- Firestore namespace helper: `lib/services/app_firestore.dart`
- Notification service: `lib/services/fcm_notification_service.dart`

### Backend

- Node.js Express service in `backend/fcm-relay`.
- Uses Firebase Admin SDK.
- Processes `fcm_outbox` documents.
- Provides REST APIs for teams, employees, attendance, salary, notifications, and migration.
- API key support exists through `BACKEND_API_KEY`, but it is optional.

### Data Namespace

The Flutter app now writes to:

```text
Attendance/main/{collection}
```

through:

```dart
FirebaseFirestore.instance.appCollection('collection_name')
```

The Firestore rules still include both legacy root collections and nested `Attendance/{appId}` collections.

## Role and Permission Audit

### Current Role Model

Application roles:

```text
employee
partialAdmin
admin
```

Organization role mapping:

```text
ADMIN, MANAGER, HR, CEO, DIRECTOR -> admin
TECH_LEAD, TEAM_LEAD -> partialAdmin
EMPLOYEE and others -> employee
```

Permission flags:

```text
canApproveLeave
canManageSalary
permissions.approveLeave
permissions.manageSalary
```

### What Is Working

- Full admin-only user creation is enforced in Flutter routing.
- Full admin-only user creation is also represented in Firestore rules.
- Partial admins can be routed away from salary/leave approval pages when their permissions are missing.
- The Create User menu entry is hidden unless the logged-in user is full admin.
- Public signup cannot create admin/partial admin users.

### Key Risk

Role logic exists in multiple places:

- `auth_role_service.dart`
- `app_router.dart`
- `firestore.rules`
- `storage.rules`
- backend admin recipient lookup
- UI menus

This duplication increases drift risk. Storage rules already appear out of sync with the app namespace and partial-admin model.

## Findings

### Critical: Storage Rules Read Legacy Root User Documents

File: `storage.rules`

The app stores user documents under:

```text
Attendance/main/users/{uid}
```

But Storage rules check:

```text
/databases/(default)/documents/users/{uid}
```

Impact:

- Employees/admins may be blocked from valid Storage access.
- Partial-admin rules are not recognized in Storage.
- Salary slip, leave document, profile photo, team logo, and company document access can behave differently from Firestore access.

Recommendation:

- Update Storage rules to read `Attendance/main/users/{uid}`.
- Add `partialAdmin`, `canManageSalary`, and `canApproveLeave` handling where relevant.
- Use full admin for company/team write access, salary managers for salary-slip writes, and owners for own employee documents.

### Critical: Backend API Key Is Optional

File: `backend/fcm-relay/src/index.js`

`requireApiKey` returns without enforcement when `BACKEND_API_KEY` is not configured.

Impact:

- If deployed without `BACKEND_API_KEY`, public callers can create teams, employees, attendance records, salary records, notifications, and trigger migration endpoints.
- The payroll upload endpoint can write salary data.

Recommendation:

- Fail startup if `BACKEND_API_KEY` is empty in production.
- Add environment variable like `ALLOW_UNAUTHENTICATED_LOCAL_DEV=true` only for local development.
- Prefer Firebase Auth ID token verification plus role/permission checks over a shared static API key.

### High: Backend REST APIs Do Not Verify Firebase User Roles

File: `backend/fcm-relay/src/index.js`

The backend uses only `x-api-key`; it does not verify Firebase Auth tokens or enforce admin/partial-admin permissions per request.

Impact:

- Any holder of the API key has broad write power.
- No user-level audit trail for salary, attendance, leave, or notification changes.
- Partial admin permissions are not enforced by backend endpoints.

Recommendation:

- Require Firebase ID token in `Authorization: Bearer <token>`.
- Load `Attendance/main/users/{uid}`.
- Enforce:
  - full admin for user creation/migration/team management
  - `canManageSalary` for salary endpoints
  - `canApproveLeave` for leave approval endpoints
  - appropriate ownership for employee self-service endpoints

### High: Client-Side Admin Screens Depend Heavily on Rules

Files:

- `lib/screens/admin_salary_screen.dart`
- `lib/screens/admin_leave_requests_screen.dart`
- `lib/screens/admin_leave_approval_screen.dart`
- `lib/router/app_router.dart`

Routing blocks some partial-admin access, but the screens themselves do not independently check permissions before executing writes. If a route is reached through a stale state, deep link, or future route addition, the UI will attempt privileged writes.

Impact:

- Firestore rules should block unauthorized writes, but the user experience will be confusing.
- If rules drift, unauthorized operations could succeed.

Recommendation:

- Add a reusable `PermissionGate` or provider using `AuthRoleService.currentAccess()`.
- In salary screens, check `canManageSalary` before enabling upload.
- In leave approval screens, check `canApproveLeave` before showing action buttons.
- Keep Firestore rules as final enforcement.

### High: Firestore Rules Have Legacy and Nested Collections With Different Semantics

File: `firestore.rules`

The rules define both:

```text
/users
/employee_profiles
/attendance
...
```

and:

```text
/Attendance/{appId}/users
/Attendance/{appId}/employee_profiles
/Attendance/{appId}/attendance
...
```

Impact:

- Security behavior can differ depending on which path a client/backend uses.
- Storage rules currently use legacy root users.
- Migration or backend code could accidentally write to a less intended path.

Recommendation:

- Choose one production namespace: `Attendance/main`.
- Remove or lock down legacy root collections after migration.
- If legacy support must remain temporarily, make root rules read-only or admin-only and document an end date.

### High: Attendance and Face Data Are Client-Generated

Files:

- `lib/services/attendance_session_service.dart`
- `lib/services/face_recognition_service.dart`

Attendance writes include GPS, face-image base64, and face-recognition templates generated on the client.

Impact:

- Client-side location and face verification can be tampered with on rooted/debug devices.
- Face templates and images are sensitive biometric data.
- Current rules allow employees to create/update their own attendance records, which is functional but high-trust.

Recommendation:

- Move final attendance decisions to Cloud Functions/backend where possible.
- Store face images in Firebase Storage, not Firestore base64 fields.
- Avoid storing raw daily face images unless absolutely necessary.
- Encrypt biometric templates or reduce stored biometric data.
- Add retention policy and deletion jobs for biometric records.

### High: Payroll Upload API Uses a Hardcoded Default Public Base URL

File: `lib/services/payroll_api_service.dart`

Default base URL:

```text
https://attendance-gk31.onrender.com
```

Impact:

- Builds can silently target a production-like backend.
- If `PAYROLL_API_KEY` is omitted, calls may still be made without a key.
- Harder to separate dev/staging/prod.

Recommendation:

- Require `PAYROLL_API_BASE_URL` and `PAYROLL_API_KEY` for admin payroll builds.
- Show a clear configuration error if missing.
- Use separate Firebase Hosting/Cloud Run environments.

### Medium: FCM Topic Subscription Is Broad

File: `lib/services/fcm_notification_service.dart`

Non-web users subscribe to `team_all`; admins/partial admins subscribe to `admin_all`.

Impact:

- Topic-based push delivery is coarse.
- Admin topic includes partial admins, even if a partial admin lacks leave/salary permissions.
- Revoked users may keep receiving topic pushes until token/topic cleanup catches up.

Recommendation:

- Prefer direct recipient tokens for sensitive notifications.
- Segment admin topics by permission:
  - `admin_all`
  - `leave_approvers`
  - `salary_managers`
- Unsubscribe users when roles change or on sign-out.

### Medium: Notification Navigation Does Not Check Partial-Admin Action Permissions

File: `lib/services/fcm_notification_service.dart`

`actionRouteForNotificationData` routes any admin-like user to leave, attendance mark, or exit request pages.

Impact:

- Partial admins may be routed to pages they cannot act on.
- Router may bounce some routes, but notification intent and UI can feel inconsistent.

Recommendation:

- Use `currentAccess()` inside notification route resolution.
- Route leave notifications to admin leave pages only if `canApproveLeave`.
- Route salary notifications to salary pages only if `canManageSalary`.

### Medium: Face Recognition Is Landmark Distance, Not Strong Identity Verification

File: `lib/services/face_recognition_service.dart`

The current algorithm compares normalized landmarks with a static threshold.

Impact:

- Vulnerable to spoofing, lighting variance, camera differences, and photos/videos.
- No liveness detection.
- May create false accepts or false rejects.

Recommendation:

- Treat it as a convenience check, not authoritative biometric authentication.
- Add liveness detection or a stronger identity provider if attendance depends on biometric proof.
- Log match confidence and failed attempts for review.

### Medium: Firestore Query Indexes May Not Cover Current Queries

Files:

- `firestore.indexes.json`
- app providers/screens

Indexes target collection groups like `attendance_records`, `salary_records`, and `notifications`. The app also queries nested collections such as `Attendance/main/team_messages`, `leave_requests`, `employee_profiles`, and `attendance`.

Impact:

- Some production queries may fail with missing index errors as data grows.
- Sorting is sometimes done client-side, which can become costly.

Recommendation:

- Capture Firestore index errors from web/mobile testing.
- Add indexes for:
  - `team_messages.createdAt desc`
  - `leave_requests.status + requestedAt/createdAt`
  - `attendance.employeeId + loginDateIst`
  - `attendance.employeeId + loginDateIst/status`
  - `employee_profiles.department/teamId`

### Medium: Rule Validation Is Not Automated

Files:

- `firestore.rules`
- `storage.rules`

No Firebase emulator rule tests are present.

Impact:

- Role and permission changes can silently break Firestore/Storage access.
- Root/nested namespace drift is easy to miss.

Recommendation:

- Add Firebase Emulator Suite tests.
- Cover:
  - employee own profile read/update
  - employee cannot read another salary
  - full admin can create users
  - partial admin cannot create users
  - partial admin with/without leave permission
  - partial admin with/without salary permission
  - Storage owner/admin access using `Attendance/main/users`

### Medium: Backend Migration Endpoint Is Powerful

Endpoint:

```text
POST /api/admin/migrate-root-to-attendance
```

Impact:

- Copies root collections into `Attendance/main`.
- If API key is absent or leaked, this endpoint can mutate production data.

Recommendation:

- Disable or remove after migration.
- Require a second confirmation token or deployment-only flag.
- Log migration actor, request ID, and copied counts.

### Medium: Salary Management Exists in Both Client and Backend

Files:

- `lib/services/attendance_session_service.dart`
- `lib/screens/admin_salary_screen.dart`
- `backend/fcm-relay/src/index.js`

Salary records can be generated from client-side attendance service and uploaded through backend payroll API.

Impact:

- Multiple sources can produce different salary calculations.
- Hard to audit salary correctness.

Recommendation:

- Centralize salary generation in backend/Cloud Functions.
- Mark salary records with `source`, `generatedByUid`, `approvedByUid`, and immutable timestamps.
- Keep client as UI only for reviewing/triggering generation.

### Low: Public Firebase Web/API Keys Are Present

File:

- `lib/firebase_options.dart`

Firebase client API keys are present. This is normal for Firebase client apps and not a secret by itself.

Risk remains if:

- Auth providers are too permissive.
- Firestore/Storage rules are weak.
- API key restrictions are missing in Google Cloud console.

Recommendation:

- Restrict Firebase API keys by Android package/SHA, iOS bundle, and web domain where possible.
- Ensure App Check is enabled for Firestore, Storage, and backend endpoints if feasible.

### Low: Several Silent Catch Blocks Hide Failures

Files:

- `lib/main.dart`
- `lib/services/fcm_notification_service.dart`
- `lib/services/attendance_session_service.dart`
- multiple screens

Impact:

- Notification, cache, and Firestore failures may be hard to diagnose.

Recommendation:

- Add structured logging for non-sensitive errors.
- Show actionable UI status for user-impacting failures.
- Keep silent catches only for truly optional best-effort operations.

### Low: Debug Logging Remains in Team Messaging

File:

- `lib/screens/team_messages_screen.dart`

Impact:

- Console noise.
- Potential leakage of workflow state.

Recommendation:

- Remove or gate behind `kDebugMode`.

## Functional Coverage Review

### Authentication

Strengths:

- Firebase Auth email/password flow is straightforward.
- Role lookup is centralized in `AuthRoleService`.
- Admin user creation uses a secondary Firebase app instance, preserving the current admin session.

Risks:

- The first full admin still needs manual provisioning.
- Role values are string-based and duplicated across rules/backend/UI.
- Firestore user documents are the source of truth, not Firebase custom claims.

Recommendations:

- Move roles/permissions to Firebase custom claims for high-value authorization.
- Keep Firestore profile data for UI, but use claims for coarse access decisions.
- Add admin bootstrap script using Firebase Admin SDK.

### Attendance

Strengths:

- Supports active sessions, office geofence, office entry/exit segments, auto logout, leave requests, and salary-related day classification.
- Uses transactions for some session writes.

Risks:

- Client writes key attendance data.
- Fixed office geofence is hardcoded.
- Device ID is derived from Android device info and uid; web/iOS handling should be reviewed.
- Face image base64 in Firestore can create large documents and privacy concerns.

Recommendations:

- Move office location to secure config.
- Store image attachments in Storage with retention.
- Add server-side finalization of attendance days.

### Notifications

Strengths:

- Handles foreground, background, and terminated message taps.
- Writes notification inbox records.
- Supports local notification display for foreground Android.
- Backend outbox has retry support.

Risks:

- Topic and direct-token delivery can duplicate notifications.
- Admin-like route handling does not always consider granular permissions.
- Web FCM requires VAPID key at build time; missing key silently results in no token.

Recommendations:

- Add a visible web setup check for missing `FIREBASE_WEB_VAPID_KEY`.
- Add notification dedupe by message ID across local and remote flows.
- Segment sensitive notifications by permission.

### Payroll

Strengths:

- Admin salary upload UI exists.
- Backend payroll upload and salary generation APIs exist.
- Salary records are namespaced under `Attendance/main`.

Risks:

- Backend API auth is weak if env missing.
- Salary logic is split between client and backend.
- Salary records can be overwritten through merge writes.

Recommendations:

- Use backend-only salary generation.
- Add record lifecycle: draft -> generated -> approved -> published.
- Store `createdBy`, `approvedBy`, and immutable audit logs.

### Web UI

Strengths:

- Admin web shell exists for wide screens.
- Create User menu is now full-admin-only.
- Same role dropdown and permission toggles are available in the web signup/create-user UI.

Risks:

- Web notification setup depends on compile-time VAPID key.
- Browser support for camera/MLKit flow may differ from Android.
- Some mobile-first workflows may need web-specific QA.

Recommendations:

- Add Playwright or integration tests for admin web:
  - login
  - create employee
  - create partial admin
  - salary permission denied/allowed
  - leave permission denied/allowed
  - notification detail navigation

## Recommended Remediation Plan

### Phase 1: Security Baseline

1. Fix Storage rules to use `Attendance/main/users`.
2. Make `BACKEND_API_KEY` mandatory outside local development.
3. Add backend Firebase ID token verification.
4. Remove or restrict legacy root Firestore collection rules.
5. Disable migration endpoint in production.

### Phase 2: Permission Consistency

1. Create a shared role/permission model document or codegen source.
2. Update notification routing to use granular permissions.
3. Add UI permission gates inside admin screens.
4. Add Firestore/Storage emulator tests.

### Phase 3: Data Integrity

1. Move salary generation to backend/Cloud Functions.
2. Add immutable audit logs for salary, leave, attendance corrections, and role changes.
3. Move face images and attachments to Storage.
4. Add retention cleanup functions for biometric and notification data.

### Phase 4: Production Hardening

1. Add App Check.
2. Restrict Firebase API keys.
3. Add CI checks:
   - `flutter analyze`
   - `flutter test`
   - backend `node --check`
   - Firebase emulator rule tests
4. Add staging/prod environment separation.

## Suggested Firebase Rules Test Matrix

| User | Operation | Expected |
|---|---|---|
| unauthenticated | read any app data | denied |
| employee | read own profile | allowed |
| employee | read another salary | denied |
| employee | create own leave request | allowed |
| employee | approve leave | denied |
| partial admin without leave permission | approve leave | denied |
| partial admin with leave permission | approve leave | allowed |
| partial admin without salary permission | write salary | denied |
| partial admin with salary permission | write salary | allowed |
| partial admin | create admin/employee user | denied |
| full admin | create admin/employee user | allowed |
| full admin | migrate/correct app data | allowed |

## Suggested Backend API Test Matrix

| Endpoint | Missing API key | Invalid Firebase token | Employee token | Partial admin token | Full admin token |
|---|---:|---:|---:|---:|---:|
| `/api/teams` POST | denied | denied | denied | denied or limited | allowed |
| `/api/employees` POST | denied | denied | denied | denied | allowed |
| `/api/salary/generate-month` | denied | denied | denied | allowed only with salary permission | allowed |
| `/api/payroll/upload` | denied | denied | denied | allowed only with salary permission | allowed |
| `/api/notifications/send` | denied | denied | denied | permission-scoped | allowed |
| `/api/admin/migrate-root-to-attendance` | denied | denied | denied | denied | allowed only with deployment flag |

## Immediate Action Items

Highest priority:

1. Fix `storage.rules` namespace mismatch.
2. Make backend API key mandatory in production.
3. Add Firebase ID token verification to backend routes.
4. Add emulator tests for Firestore and Storage rules.
5. Remove production access to the migration endpoint.

Next priority:

1. Add screen-level permission gates for salary and leave screens.
2. Update FCM routing to respect granular permissions.
3. Move salary generation and attendance finalization server-side.
4. Move face images out of Firestore and into Storage with retention.

## Final Assessment

The app is a strong prototype moving toward a production attendance/payroll system. The UI and Firebase integration are mostly coherent, and recent role-selection changes are correctly moving the product toward admin-only user management and partial-admin permissioning.

The largest gap is that production-grade security still depends on multiple duplicated client/rules/backend checks. For a payroll and attendance app, the next engineering focus should be centralizing authorization, validating Firebase rules with tests, hardening backend APIs, and moving high-trust calculations to backend-controlled code.
