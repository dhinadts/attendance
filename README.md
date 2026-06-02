# WorkSync Pro

WorkSync Pro is a Flutter and Firebase attendance management application for employee attendance, leave approvals, salary records, push notifications, and agile task tracking.

The app currently supports employee, admin, and partial-admin access. It is designed around Firebase Authentication, Cloud Firestore, Firebase Cloud Messaging, Firebase Storage-ready data paths, and an optional Node.js FCM relay backend.

## Current Status

This application is suitable for internal demo and staged QA. Core app flows are implemented, including attendance, leave, notifications, salary records, role-based routing, and agile task assignment. Production deployment still requires strict Firebase rules review, device testing, backend hardening, and policy configuration.

## Tech Stack

- Flutter / Dart
- Firebase Authentication
- Cloud Firestore
- Firebase Cloud Messaging
- flutter_local_notifications
- go_router
- Riverpod / Flutter Riverpod
- Node.js backend relay in `backend/fcm-relay`
- CSV/XLSX task import using `file_picker` and `excel`

## Main Features

### Authentication And Roles

- Email and password login.
- Signup role groups:
  - `admin`
  - `employee`
  - `partialAdmin`
- Admin-like roles can open admin routes.
- Full admin can create users.
- Partial admins can be given limited permissions such as leave approval or salary management.

Role mapping is managed in:

```text
lib/constants/organization_options.dart
lib/services/auth_role_service.dart
```

### Teams And Employee Roles

Supported teams include:

```text
TECH
OPERATIONS
SALES
ANALYST
MARKETING
CEO
DIRECTOR
```

Supported employee roles include:

```text
CEO
DIRECTOR
SENIOR SOFTWARE DEVELOPER
JUNIOR SOFTWARE DEVELOPER
DEVELOPER
TESTER
RELATIONSHIP MANAGER
EXECUTIVE
EMPLOYEE
```

### Attendance

- Face-authenticated attendance flow.
- Attendance calendar.
- Daily attendance status:
  - Present
  - Absent
  - Leave
  - Approved leave
  - Requested leave
  - Rejected leave
  - Not considered
- Employee attendance tab reflects leave approval/rejection details below the calendar selection.
- Attendance records are stored under the app namespace:

```text
Attendance/main/attendance/{employeeId_yyyy-MM-dd}
```

### Leave Approval

Admin approval screens now show:

- Pending leave requests.
- Approved and rejected history in the same screen.
- Approved/rejected by whom.
- Approved/rejected date and time.
- Admin approval note or rejection reason.

Employee login reflects approval or rejection in the attendance details screen.

### Salary

- Admin salary management screen.
- Employee salary download screen.
- Salary records stream from Firestore.
- Salary generated/uploaded date can be displayed in employee updates.

Salary records use:

```text
Attendance/main/salary_records/{recordId}
```

### Notifications And FCM

- Foreground, background, and terminated-state notification handling.
- Notification bell with unread count.
- Admin notification screens by team and employee.
- Employee update panel shows relevant push notifications.
- FCM outbox pattern:

```text
Attendance/main/fcm_outbox/{messageId}
```

The Flutter app writes notification requests. The backend relay or Firebase Functions should send real push notifications from the server side.

### Agile Task And Scrum Module

Admin and partial-admin users can assign work through:

```text
/admin-tasks
```

Employees update their work through:

```text
/tasks
```

Task features:

- Single task creation.
- Bulk import by CSV or XLSX.
- Jira-style ticket key.
- Team assignment.
- Employee assignment.
- Priority.
- Task status.
- Daily scrum update.
- Timesheet hours.
- Blockers.
- Manager feedback.
- Achievements.
- Improvements.

Task records use:

```text
Attendance/main/tasks/{taskId}
```

### Task Import Format

Admin task import supports `.csv` and `.xlsx`.

Expected columns:

```text
ticketKey,title,description,employeeId,employeeName,team,priority
```

Required columns:

```text
title
employeeId
```

Optional columns:

```text
ticketKey
description
employeeName
team
priority
```

Allowed priorities:

```text
low
medium
high
urgent
```

If `employeeName` or `team` is missing, the app tries to fill them from `employee_profiles`.

## Firebase Structure

The app is moving toward a single namespaced Firestore structure:

```text
Attendance/main/users
Attendance/main/employee_profiles
Attendance/main/attendance
Attendance/main/leave_requests
Attendance/main/salary_records
Attendance/main/salary_structures
Attendance/main/tasks
Attendance/main/team_messages
Attendance/main/fcm_outbox
Attendance/main/fcm_tokens
Attendance/main/notification_inbox
Attendance/main/notification_reads
Attendance/main/exit_requests
Attendance/main/audit_logs
Attendance/main/fcm_background_events
```

The helper is:

```text
lib/services/app_firestore.dart
```

Use this pattern in Flutter:

```dart
FirebaseFirestore.instance.appCollection('collection_name')
```

## Firebase Storage Recommendation

Recommended storage hierarchy:

```text
attendance-app/
  teams/
    {teamId}/logo/
  users/
    {employeeId}/profile/
  attendance/
    {employeeId}/{yyyy-MM-dd}/attachments/
  leave-documents/
    {employeeId}/{requestId}/
  salary-slips/
    {employeeId}/{yyyy-MM}/
  announcements/
    {announcementId}/attachments/
  company-documents/
```

## Backend Relay

Backend folder:

```text
backend/fcm-relay
```

Purpose:

- Listen to pending FCM outbox documents.
- Send push notifications through Firebase Admin SDK.
- Provide optional API endpoints for employees, attendance, salary, notification, and migration tasks.

Run locally:

```powershell
cd backend/fcm-relay
npm install
npm start
```

Important environment variables:

```text
FIREBASE_PROJECT_ID
FIREBASE_SERVICE_ACCOUNT_BASE64
FCM_RELAY_DRY_RUN=false
```

Never commit Firebase service account JSON.

## Local Development

Install Flutter packages:

```powershell
flutter pub get
```

Analyze:

```powershell
flutter analyze
```

Run app:

```powershell
flutter run
```

Build Android APK:

```powershell
flutter build apk --release
```

Backend syntax check:

```powershell
npm --prefix backend/fcm-relay run check
```

## Demo Users

Demo users seeded earlier:

```text
CEO
Email: ceo@gmail.com
Password: Qwerty@123

Director
Email: director@gmail.com
Password: Qwerty@123

Employee
Email: emp1@gmail.com
Password: Qwerty@123
```

## Important Files

```text
lib/router/app_router.dart
lib/widgets/app_shell.dart
lib/widgets/admin_bottom_nav.dart
lib/widgets/employee_bottom_nav.dart
lib/screens/owner_dashboard_screen.dart
lib/screens/employee_dashboard_screen.dart
lib/features/tasks/presentation/screens/task_board_screen.dart
lib/screens/admin_leave_requests_screen.dart
lib/screens/admin_leave_approval_screen.dart
lib/screens/attendance_details_screen.dart
lib/services/auth_role_service.dart
lib/services/attendance_session_service.dart
lib/services/fcm_notification_service.dart
lib/services/app_firestore.dart
firestore.rules
backend/fcm-relay/src/index.js
```

## Audit Report

### What Is Working

- Firebase Auth login and signup are implemented.
- Admin, employee, and partial-admin route guards exist.
- Employee dashboard and admin dashboard are separated.
- Employee bottom navigation includes Home, Attendance, Log, Tasks, Salary, and Exit.
- Profile is accessible from the app bar.
- Settings icon is available in the app bar.
- Admin dashboard has compact summary, quick actions, recent activity, task access, notification access, and payroll access.
- Leave requests can be approved/rejected.
- Approved/rejected leave history is shown in the admin leave screen.
- Employee attendance details reflect leave approval/rejection.
- FCM notification routing exists for foreground/background/terminated app launch.
- Notification inbox/read tracking exists.
- Task assignment module exists for admin/partial-admin.
- Employee task/scrum/timesheet updates exist.
- Admin task import supports CSV and XLSX.
- Firestore rules include namespaced `Attendance/{appId}` rules.
- `flutter analyze` passes.

### Current Risks

- Firestore rules still include both legacy root collections and `Attendance/main` namespaced collections. Production should standardize on one structure.
- Some admin-like access is broad. Partial-admin permissions should be reviewed against company policy.
- Attendance and salary calculations are still client-heavy. Production payroll should validate calculations server-side.
- FCM delivery depends on the relay/backend or Cloud Functions being deployed and correctly configured.
- Face detection confirms a face exists, but does not prove identity unless a separate identity matching process is added.
- Task import validates required fields but does not yet enforce all business rules, such as due dates, sprint ownership, or duplicate ticket keys.
- Notification lists and task lists currently use broad streams. Production scale should add pagination and query indexes.
- Salary slip file storage and Firebase Storage rules need final production implementation if PDFs are uploaded to Firebase Storage.
- There is limited automated test coverage for auth, leave approval, FCM navigation, payroll, and task import.

### Recommended Production Work

1. Standardize Firestore to only:

```text
Attendance/main/{collection}
```

2. Deploy and verify Firestore rules.

3. Add server-side validation for:

- Attendance closure.
- Salary generation.
- Leave approval.
- Task import.
- Role and permission changes.

4. Add composite indexes for production queries:

- `leave_requests`: `employeeId`, `date`, `status`
- `attendance`: `employeeId`, `loginDateIst`
- `salary_records`: `employeeId`, `monthKey`
- `tasks`: `assignedToEmployeeId`, `status`, `updatedAt`
- `team_messages`: `createdAt`, `targetType`

5. Add automated tests:

- Role routing tests.
- Leave approval/rejection tests.
- Task import parser tests.
- Attendance status tests.
- FCM route resolution tests.

6. Add admin audit logs for:

- User creation.
- Role changes.
- Leave approvals/rejections.
- Salary generation.
- Task imports.

7. Add production task fields:

- Sprint.
- Due date.
- Estimate hours.
- Story points.
- Reviewer.
- Completion date.
- Acceptance criteria.

8. Add pagination for:

- Notifications.
- Team messages.
- Tasks.
- Attendance logs.

9. Add secure backend APIs for:

- Bulk imports.
- Salary generation.
- Scheduled attendance closing.
- FCM dispatch.

10. Create a Firebase Storage rules file before enabling uploaded salary slips or leave documents.

## Deployment Checklist

- Run `flutter analyze`.
- Run backend syntax check.
- Confirm Firebase project configuration.
- Deploy Firestore rules.
- Deploy or host FCM relay backend.
- Configure Firebase service account environment variable on backend host.
- Test Android notifications in:
  - Foreground
  - Background
  - Terminated state
- Test admin leave approval notification click.
- Test employee leave reflection.
- Test task assignment and employee scrum update.
- Test CSV and XLSX task import.
- Test salary record display.

## Suggested Current App Name

The UI currently uses:

```text
WorkSync Pro
```

See `APP_NAME_SUGGESTIONS.md` for more naming options.
