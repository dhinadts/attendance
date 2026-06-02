# Complete Frontend and Backend Audit Report

Date: 2026-06-02  
Project: WorkSync Pro / Attendance App  
Workspace: `D:\myproducts\attendance`

## Audit Scope

This audit reviewed:

- Flutter frontend compile health.
- Node.js backend syntax health.
- Route and navigation tree consistency.
- Admin and employee UI navigation.
- FCM notification route mapping.
- Task management frontend/backend alignment.
- Firestore rules for task, leave, salary, attendance, notification, and role flows.
- Documentation and backend API readiness.

## Verification Results

### Flutter Analyze

```text
Command: flutter analyze
Result: Passed
Output: No issues found
```

### Flutter Tests

```text
Command: flutter test
Result: Passed
Output: 2 tests passed
```

Current test coverage is small and mostly widget-level, so this confirms baseline health but not full business-flow coverage.

### Backend Syntax Check

```text
Command: npm --prefix backend\fcm-relay run check
Result: Passed
Output: node --check src/index.js && node --check src/seed-demo-users.js
```

### Route Target Check

All static `context.go('/route')` targets found in `lib` match a declared `GoRoute`.

```text
Missing static route targets: none
```

## Current Application Architecture

### Frontend

Main Flutter areas:

```text
lib/router/app_router.dart
lib/widgets/app_shell.dart
lib/widgets/admin_bottom_nav.dart
lib/widgets/employee_bottom_nav.dart
lib/screens/owner_dashboard_screen.dart
lib/screens/employee_dashboard_screen.dart
lib/screens/task_board_screen.dart
lib/screens/admin_leave_requests_screen.dart
lib/screens/admin_leave_approval_screen.dart
lib/screens/attendance_details_screen.dart
lib/services/fcm_notification_service.dart
lib/services/auth_role_service.dart
lib/services/attendance_session_service.dart
lib/services/app_firestore.dart
```

### Backend

Backend folder:

```text
backend/fcm-relay
```

Main backend files:

```text
backend/fcm-relay/src/index.js
backend/fcm-relay/src/seed-demo-users.js
backend/fcm-relay/README.md
```

### Firestore Namespace

The Flutter app uses:

```text
Attendance/main/{collectionName}
```

through:

```dart
FirebaseFirestore.instance.appCollection('collection_name')
```

## UI Tree Audit

### Employee Login UI Tree

Employee bottom navigation is now:

```text
Home
Attendance
Log
Tasks
Salary
Exit
```

Profile was removed from the employee bottom navigation as requested. Profile remains accessible from the app bar profile icon.

Employee app bar now includes:

```text
Notifications
Messages
Settings
Profile
```

Employee dashboard title:

```text
WorkSync Pro
```

Employee dashboard includes:

- Today attendance card.
- Calendar shortcut.
- Salary shortcut.
- Tasks shortcut.
- Exit request shortcut.
- My Updates panel:
  - Leave approval/rejection updates.
  - Salary generated records.
  - Relevant push notifications.
  - Assigned task updates.

Employee task screen:

```text
/tasks
```

Employee can:

- View assigned tasks.
- Update task status.
- Submit daily scrum update.
- Enter blocker.
- Enter timesheet hours.

### Admin Login UI Tree

Admin bottom navigation is:

```text
Admin
Employees
Payroll
Tasks
Settings
```

Admin dashboard includes:

- Compact Today's Summary row.
- Reduced Quick Action cards.
- Quick actions:
  - Mark Attendance
  - Payroll
  - Leaves
  - Tasks
  - Push
  - Reports
- Recent Activity stream:
  - Employee leave requests.
  - Push notifications.
  - Employee achievements and feedback from task/scrum flow.

Admin task screen:

```text
/admin-tasks
```

Admin/partial admin can:

- Create a single task.
- Import CSV/XLSX task rows.
- View team task status.
- Add feedback.
- Add achievements.
- Add improvements.

### Partial Admin UI Tree

Partial admin is treated as admin-like for route access. Current allowed admin-like areas include task management. Leave and salary are additionally guarded by permission flags where applicable.

Current concern:

- Partial admin can create/delete tasks through Firestore rules because `appIsAdmin(appId)` includes partial admin.
- This matches the requested manager/senior/relationship-manager assignment ability, but production may need finer permission flags like `canManageTasks`.

## Route Audit

Declared important routes:

```text
/dashboard
/attendance-details
/attendance-log
/tasks
/salary
/exit-company
/profile
/settings
/notifications
/messages

/admin-dashboard
/admin-employees
/admin-salary
/admin-tasks
/admin-leave-requests
/admin-leave-approval
/admin-notifications
/admin-messages
/admin-settings
/admin-profile
```

Result:

- Static route targets are valid.
- AppShell root path list includes task routes.
- Back behavior should not bounce users away from task routes.

## Notification Audit

FCM service:

```text
lib/services/fcm_notification_service.dart
```

Verified and corrected:

- `leave_response` now opens `/attendance-details`.
- `salary_generated` now opens `/salary`.
- `task_assigned` now opens `/tasks`.

Admin notification routing:

- Leave request opens admin leave approval when employee/date data is present.
- Attendance mark request opens admin mark attendance.
- Exit request opens admin exit request.
- Admin employee notification details route remains available.

Backend FCM payload now includes:

```text
taskId
ticketKey
```

for task assignment messages.

## Task Management Audit

### Frontend Task Collection

Flutter writes task documents to:

```text
Attendance/main/tasks/{taskId}
```

Main fields:

```text
ticketKey
title
description
team
priority
status
assignedToEmployeeId
assignedToName
assignedByUid
assignedByName
assignedByRole
scrumReports
latestScrumSummary
latestBlocker
latestHours
latestFeedback
latestAchievement
latestImprovement
feedbackByUid
feedbackByName
createdAt
createdAtIst
updatedAt
updatedAtIst
```

### Frontend Import

Admin task import supports:

```text
CSV
XLSX
```

Expected columns:

```text
ticketKey,title,description,employeeId,employeeName,team,priority
```

Required:

```text
title
employeeId
```

### Backend Task APIs

Backend task APIs were added:

```text
GET /api/tasks
GET /api/tasks/:taskId
POST /api/tasks
POST /api/tasks/import
PATCH /api/tasks/:taskId/scrum
PATCH /api/tasks/:taskId/feedback
PATCH /api/tasks/:taskId/status
```

Backend supports:

- Employee lookup by `employeeId`.
- Task assignment.
- Bulk task import.
- Status update.
- Scrum update.
- Timesheet hours.
- Manager feedback.
- Achievement and improvement fields.
- Optional assignment notification through `fcm_outbox`.

### Frontend/Backend Alignment

Aligned:

- Both use `Attendance/main/tasks`.
- Both use `assignedToEmployeeId`.
- Both use `ticketKey`, `title`, `description`, `team`, `priority`, `status`.
- Both use `scrumReports`.
- Both support feedback, achievement, improvement fields.

Important note:

- The Flutter task screen currently writes directly to Firestore.
- The backend task APIs are available for web admin, external integrations, scheduled processing, or future migration.
- If the product requirement is "all task imports must go through backend", the Flutter task import should be changed to call `POST /api/tasks/import` instead of writing directly to Firestore.

## Backend Audit

Backend health:

- Node syntax passes.
- FCM relay listener remains intact.
- Task routes are added without breaking existing salary, attendance, notification, or payroll routes.
- `tasks` is included in root-to-`Attendance/main` migration list.

Backend security:

- `BACKEND_API_KEY` is optional.
- If `BACKEND_API_KEY` is not configured, backend APIs are open.

Production recommendation:

```text
Set BACKEND_API_KEY in every deployed environment.
```

## Firestore Rules Audit

Rules file:

```text
firestore.rules
```

Task rules exist in both:

```text
/tasks/{taskId}
/Attendance/{appId}/tasks/{taskId}
```

Current task rule behavior:

- Admin and partial admin can read/create/update/delete tasks.
- Employee can read assigned tasks.
- Employee can update only own assigned task fields:
  - `status`
  - `latestScrumSummary`
  - `latestBlocker`
  - `latestHours`
  - `scrumReports`
  - `updatedAt`
  - `updatedAtIst`

Concern:

- Backend uses Firebase Admin SDK and bypasses Firestore rules. Backend API key protection is therefore mandatory in production.
- Partial admin task permissions are broad. Add task-specific permission flags for production.

Recommended future permission flags:

```text
canManageTasks
canAssignTasks
canReviewTasks
canImportTasks
```

## Leave Flow Audit

Admin leave screens:

- Pending requests display.
- Approved/rejected history displays in same screen.
- Decision metadata is saved:
  - decision by UID/email/name
  - decision time
  - approved/rejected specific fields
  - admin reason

Employee attendance screen:

- Selected calendar date shows leave status.
- Shows approved/rejected by.
- Shows decision time.
- Shows approval note or rejection reason.

Notification route:

- Leave response now routes to `/attendance-details`.

Status:

```text
Good for demo and QA.
```

## Salary Flow Audit

Frontend:

- Admin salary screen exists.
- Employee salary screen exists.
- Salary generated records can appear in employee updates.

Backend:

- Salary structure API exists.
- Monthly salary generation API exists.
- Legacy payroll upload API exists.

Concern:

- Production payroll should be server-authoritative. Avoid relying only on client-side calculations or uploads.

## Attendance Flow Audit

Frontend:

- Face attendance flow exists.
- Calendar and logs exist.
- Attendance details reflect leave status.

Backend:

- Check-in/check-out APIs exist.
- Daily close API exists.
- Monthly summary helper exists.

Concern:

- There are two attendance collection concepts:
  - `attendance`
  - `attendance_records`
- The Flutter app mostly uses `attendance`.
- Backend attendance APIs use `attendance_records`.

Production recommendation:

Standardize attendance writes and salary calculation source before production payroll.

## Data Model Audit

Current app namespace:

```text
Attendance/main/users
Attendance/main/employee_profiles
Attendance/main/attendance
Attendance/main/attendance_records
Attendance/main/leave_requests
Attendance/main/salary_records
Attendance/main/salary_structures
Attendance/main/tasks
Attendance/main/team_messages
Attendance/main/fcm_outbox
Attendance/main/fcm_tokens
Attendance/main/notifications
Attendance/main/notification_inbox
Attendance/main/notification_reads
Attendance/main/exit_requests
```

Risk:

- Legacy root collections still exist in rules and backend migration support.

Recommendation:

- Freeze new development on `Attendance/main/{collection}` only.
- Migrate any root data once.
- Remove root collection rules after migration.

## Build And Dependency Audit

Recently added dependencies:

```text
file_picker
excel
```

Impact:

- Enables CSV/XLSX task import.
- `flutter pub get` updated platform plugin registrants.

Potential risk:

- Excel parsing should be tested on Android and Web if both are production targets.

## Findings

### P0 Critical

No P0 compile-blocking or syntax-blocking issues found.

### P1 High

1. Backend APIs are open if `BACKEND_API_KEY` is not set.

Impact:

- Anyone with backend URL can create employees, tasks, salary records, or notifications.

Fix:

- Set `BACKEND_API_KEY`.
- Consider Firebase Auth ID token verification for admin APIs.

2. Attendance source mismatch exists between frontend and backend.

Impact:

- Salary generation may not match Flutter attendance data if backend reads `attendance_records` while Flutter writes `attendance`.

Fix:

- Standardize on one attendance collection or sync both consistently.

3. Firestore root and namespaced structures both remain active.

Impact:

- Data can split across legacy and new paths.

Fix:

- Migrate and lock to `Attendance/main`.

### P2 Medium

1. Flutter task import writes directly to Firestore.

Impact:

- Backend validation is bypassed.

Fix:

- For production, call `POST /api/tasks/import` from admin web/mobile or move import fully server-side.

2. Partial admin task permission is broad.

Impact:

- Any partial admin can create/delete tasks.

Fix:

- Add `canManageTasks` permission.

3. Notification route now supports tasks/salary/leave, but task-specific detail screen does not exist.

Impact:

- Task notification opens task list, not exact task detail.

Fix:

- Add `/tasks?taskId=...&open=1` support or a task detail route.

4. Test coverage is too small.

Impact:

- Business flow regressions may pass CI.

Fix:

- Add tests for auth routing, leave approval, task import, FCM route mapping, and salary generation.

### P3 Low

1. Some admin screens use broad bottom nav indexes.

Impact:

- Highlighting may not perfectly represent sub-sections.

Fix:

- Optional: add more admin nav items or section-specific highlighting rules.

2. App name is mixed historically in docs and package name.

Impact:

- Cosmetic and branding inconsistency.

Fix:

- Standardize display name to `WorkSync Pro`; keep package name only if acceptable.

## Recommended Next Work

1. Add backend ID-token verification for admin APIs.
2. Add `canManageTasks` permission to user records, route guards, and Firestore rules.
3. Decide whether task import is direct Firestore or backend-only.
4. Standardize attendance source for payroll.
5. Add task detail route and task notification deep link.
6. Add Firestore indexes:

```text
tasks: assignedToEmployeeId + updatedAtIst
tasks: teamId + status
tasks: status + updatedAtIst
leave_requests: employeeId + date
attendance: employeeId + loginDateIst
salary_records: employeeId + monthKey
team_messages: createdAt
```

7. Add automated tests:

```text
flutter test test/fcm_route_test.dart
flutter test test/task_import_test.dart
flutter test test/auth_route_guard_test.dart
flutter test test/leave_approval_test.dart
```

8. Add backend tests for:

```text
POST /api/tasks
POST /api/tasks/import
PATCH /api/tasks/:taskId/scrum
PATCH /api/tasks/:taskId/feedback
```

## Final Assessment

Frontend and backend are currently consistent enough for demo and QA:

- Flutter analyzer passes.
- Flutter widget tests pass.
- Backend syntax check passes.
- Static route targets are valid.
- Admin/employee task UI exists.
- Backend task APIs exist.
- Firestore task rules exist.
- Notification routing was corrected for leave response, salary generated, and task assignment.

Production readiness:

```text
Not fully production-ready yet.
```

Main blockers before production:

- Secure backend APIs.
- Standardize attendance collections.
- Decide backend-only versus client-direct task imports.
- Add task-specific permission flags.
- Add functional test coverage.
- Deploy and verify Firebase rules/backend on real devices.
