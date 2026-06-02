#### Make it for multiple comapnies

# attendance

`attendance` is a Flutter-based employee attendance, salary, leave, exit-request, and team notification application built for Android-first workplace usage.

The app is designed for small and growing teams that need a lightweight way to capture face-authenticated attendance, track office time, calculate payroll from attendance records, and communicate with employees through Firebase-powered notifications.

## Product Value

- Reduces manual attendance follow-up with face login and geofence-based check-in.
- Helps payroll teams calculate salary from actual working days and office minutes.
- Gives employees one place for attendance history, salary slips, profile updates, exit requests, and team notifications.
- Supports admin-to-all, admin-to-team, team-to-team, user-to-user, user-to-admin, and admin-to-user messaging patterns.
- Keeps role-based views clean: employees see employee workflows, admins see review and broadcast workflows.

## Tech Stack

- **Flutter / Dart**: Mobile app UI and business flow.
- **Firebase Auth**: Email/password login and session persistence.
- **Cloud Firestore**: Attendance, profile, leave, salary, exit, messaging, notification-read state.
- **Firebase Cloud Messaging**: Push notifications for topics and direct user delivery.
- **Firebase Functions or FCM Relay Backend**: Server-side FCM trigger from `fcm_outbox`.
- **flutter_local_notifications**: Foreground local notifications and notification modal support.
- **camera**: Face capture.
- **google_mlkit_face_detection**: Face detection before marking attendance.
- **geolocator**: Current-location and geofence tracking.
- **path_provider**: Salary PDF file storage.
- **go_router**: Role-based route navigation.

## Core Features

### Authentication And Roles

- Email/password login and signup.
- Session persistence through Firebase Auth.
- Role-based routing:
  - Employee dashboard and employee modules.
  - Admin dashboard and approval/broadcast modules.
- Supported signup roles:
  - Employee
  - Admin

### Teams And Employee Roles

Configured teams:

- `TECH`
- `OPERATIONS`
- `SALES`
- `ANALYST`
- `MARKETING`
- `CEO`
- `DIRECTOR`

Configured employee roles:

- `SENIOR SOFTWARE DEVELOPER`
- `JUNIOR SOFTWARE DEVELOPER`
- `DEVELOPER`
- `TESTER`
- `RELATIONSHIP MANAGER`
- `EXECUTIVE`
- `EMPLOYEE`

### Attendance

- Daily face-authenticated check-in.
- Current login location becomes the 10-meter attendance zone.
- Daily attendance documents use deterministic IDs:
  - `attendance/{employeeId_yyyy-MM-dd}`
- Session records include in-office segments.
- Minimum 7 office hours required for attendance consideration.
- Auto logout after 9 hours.
- Calendar view statuses:
  - Present
  - Leave
  - Absent
  - Approved Leave
  - Requested Leave
  - Not Considered

### Salary

- Monthly salary records use:
  - `salary_records/{employeeId_yyyy-MM}`
- Salary slip generation is based on attendance records.
- Month/year selection is available.
- Salary slip PDF is generated and saved locally.

### Leave Requests

- Leave request document ID:
  - `leave_requests/{employeeId_yyyy-MM-dd}`
- Duplicate leave request prevention is included.
- Leave cannot be requested for a completed attendance-considered day.

### Exit Company

- Employee can submit relieving request with:
  - Subject
  - Reason
  - Leaving date
- Duplicate pending exit request prevention is included.
- Exit requests are stored under:
  - `exit_requests/{employeeId_requestId}`

### Profile

Editable employee profile fields:

- Employee ID
- Nick name
- First name
- Last name
- DOB
- Contact number
- Email
- Joining date
- Department/team
- Role

Profile updates are stored in Firebase and local cache.

### Notifications And Messaging

- Notification bell in app bar with unread badge.
- Separate notifications screen with news-reader style layout.
- Read/unread status stored in:
  - `notification_reads/{uid_messageId}`
- Message broadcast flow:
  - Flutter app writes to `team_messages`.
  - Flutter app writes pending push request to `fcm_outbox`.
  - Firebase Function or `backend/fcm-relay` listens to `fcm_outbox/{messageId}`.
  - Server backend sends FCM push to topics or direct user tokens.

Supported messaging scenarios:

- Admin to all teams
- Admin to selected teams
- Admin to user
- Team to team
- User to user
- User to admin

## Firebase Data Model

Main collections:

```text
users/{uid}
employee_profiles/{employeeId}
attendance/{employeeId_yyyy-MM-dd}
leave_requests/{employeeId_yyyy-MM-dd}
salary_records/{employeeId_yyyy-MM}
exit_requests/{employeeId_requestId}
team_messages/{messageId}
fcm_outbox/{messageId}
fcm_tokens/{uid_platform}
notification_inbox/{notificationId}
notification_reads/{uid_messageId}
fcm_background_events/{eventId}
```

## FCM Behavior

### Foreground

- FCM message is received in-app.
- Local notification is shown.
- Modal dialog appears with:
  - `CLEAR`
  - `OPEN`
- Message is stored in `notification_inbox`.

### Background

- Notification appears in Android notification tray.
- Tapping notification opens messages/notifications route.
- Background event is best-effort logged.

### Terminated

- Initial FCM message is captured using `getInitialMessage()`.
- After app starts and navigator is available, app opens the correct message route.

## Free Push Notification Demo

FCM is free. For a free demo without Firebase Functions deployment:

1. Run the app and login.
2. Ensure the user is subscribed to topics like:
   - `team_all`
   - `team_tech`
   - `team_operations`
   - `admin_all`
3. Open Firebase Console.
4. Go to Messaging.
5. Create a notification campaign.
6. Target a topic such as `team_all` or `team_tech`.
7. Send the message.

This verifies real push delivery for foreground, background, and terminated app states.

For automated user-to-user push, run either Firebase Functions or the standalone FCM relay backend.

## Free Backend FCM Relay

This repository includes a standalone Node backend:

```text
backend/fcm-relay
```

Use it when you want automatic push notifications without deploying Firebase Functions.

Run locally:

```powershell
cd backend/fcm-relay
npm install
$env:FIREBASE_PROJECT_ID="your-project-id"
$env:FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account","project_id":"your-project-id", ... }'
npm start
```

Deploy on Render/Railway:

- Root directory: `backend/fcm-relay`
- Build command: `npm install`
- Start command: `npm start`
- Health check path: `/health`

If Render root directory is set to `backend`, use:

- Root directory: `backend`
- Build command: `npm run build`
- Start command: `npm start`
- Health check path: `/health`

Required environment variables:

```text
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_SERVICE_ACCOUNT_BASE64=base64-encoded-full-service-account-json
FCM_RELAY_DRY_RUN=false
```

Create the base64 value in PowerShell from the downloaded Firebase service account JSON:

```powershell
[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((Get-Content .\firebase-service-account.json -Raw)))
```

The relay watches `fcm_outbox` documents with `status: pending` or `status: retry`, sends the push through Firebase Admin SDK, and updates the document to `sent`, `failed`, or `retry`.

Important: never place service account JSON in the Flutter app, and never commit it to git.

## Firebase Deployment

Install dependencies:

```powershell
cd functions
npm install
```

Deploy Firestore rules and Functions:

```powershell
firebase login
firebase use inmakes-87ea0
firebase deploy --only firestore:rules,functions
```

Deploy separately:

```powershell
firebase deploy --only firestore:rules
firebase deploy --only functions
```

Firebase Functions may require the Blaze plan and these APIs:

- Cloud Functions
- Cloud Build
- Artifact Registry

## Local Development

Install Flutter dependencies:

```powershell
flutter pub get
```

Run analyzer:

```powershell
flutter analyze lib
```

Build Android release:

```powershell
flutter build apk --release
```

If local Dart analytics causes permission issues on Windows, use:

```powershell
$env:DART_ANALYTICS_DISABLED='true'
$env:APPDATA='D:\dhinadts\products\attendance\.appdata'
$env:PUB_CACHE='D:\dhinadts\products\attendance\.pub-cache'
flutter analyze lib
```

## Audit Report

### Completed

- App name set to `attendance`.
- Firebase Auth login and signup added.
- Auth persistence and role-based route guards added.
- Employee/admin route separation added.
- Drawer navigation added.
- Back navigation improved with fallback routing.
- Face attendance flow implemented.
- Attendance daily document IDs implemented.
- Attendance segment model added for office-minute calculation.
- 7-hour eligibility logic added.
- 9-hour auto logout logic added.
- Leave request duplicate prevention added.
- Exit request validation and duplicate pending prevention added.
- Salary generation from attendance records added.
- Salary PDF generation added.
- Profile validation added.
- Team and role master lists added.
- FCM foreground, background, and terminated handling added.
- Notification bell with unread badge added.
- Separate notification reader screen added.
- Firestore security rules added.
- Firebase Function trigger for `fcm_outbox` added.

### Pending Tasks

- Deploy Firestore rules to Firebase.
- Deploy Firebase Functions for automatic FCM delivery.
- Test FCM on real Android device for foreground/background/terminated states.
- Add admin approval screens for leave and exit requests.
- Add admin salary review/finalization workflow.
- Add holiday and weekly-off calendar support.
- Add overtime, unpaid leave, paid leave, and deduction policy settings.
- Add stronger admin creation flow. Admin signup should be controlled in production.
- Add profile-change approval for sensitive fields like employee ID, joining date, department, and role.
- Add Firestore composite indexes if production queries require them.
- Add pagination for notifications and team messages.
- Add attachment support for salary slips if slips need to be uploaded/shared.
- Add test coverage for attendance calculations, salary calculations, and route guards.

### Risks And Notes

- FCM direct sending from Flutter app is intentionally not implemented because server credentials must never be placed inside an APK.
- The app-side trigger writes to `fcm_outbox`; server-side Firebase Function sends the real push.
- Notification badge currently reads latest messages from Firestore. For very large production use, move to per-user notification documents for cheaper reads.
- Face detection verifies that a face exists, but it does not yet verify a specific registered identity. True face recognition requires a separate biometric matching service or approved on-device model.
- Background location behavior depends on Android battery and permission policy. Test on target devices before production payroll use.

## Project Status

The app is now suitable for a functional internal demo:

- Employee attendance demo
- Salary slip demo
- Leave/exit request demo
- Admin/team notification demo
- Firebase Console topic push demo

For production, complete the pending deployment, approval workflows, salary policy rules, and device testing.
