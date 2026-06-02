# attendance Backend and FCM Relay

Standalone Node backend for attendance APIs, salary generation, notification queueing, and Firebase Cloud Messaging delivery without Firebase Cloud Functions.

Firestore writes are namespaced under:

```text
Attendance/main/{collectionName}
```

Override with:

```text
FIRESTORE_APP_ROOT_COLLECTION=Attendance
FIRESTORE_APP_ROOT_DOCUMENT=main
```

The Flutter app writes pending push jobs to:

```text
fcm_outbox/{messageId}
```

This service watches that collection and sends the notification using Firebase Admin SDK.

## Why This Exists

Firebase Cloud Messaging is free, but deploying Firebase Cloud Functions usually requires the Firebase Blaze plan. This relay can run on a free Node hosting tier such as Render or Railway and perform the same `fcm_outbox` delivery job.

## Required Firebase Setup

1. Open Firebase Console.
2. Go to Project Settings.
3. Open Service accounts.
4. Generate a new private key.
5. Do not commit that JSON file.
6. Add the JSON content to your hosting provider environment variable:

```text
FIREBASE_SERVICE_ACCOUNT_JSON
```

Alternative: base64 encode the JSON and use:

```text
FIREBASE_SERVICE_ACCOUNT_BASE64
```

## Local Run

```powershell
cd backend/fcm-relay
npm install
copy .env.example .env
npm start
```

For local `.env` support, set variables in your terminal or use your hosting provider settings. This service intentionally does not require `dotenv` in production.

PowerShell example:

```powershell
$env:FIREBASE_PROJECT_ID="your-project-id"
$env:FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account","project_id":"your-project-id", ... }'
npm start
```

## Render Setup

Create a new Web Service. Recommended setup:

- Root Directory: `backend/fcm-relay`
- Build Command: `npm install`
- Start Command: `npm start`
- Health Check Path: `/health`

If you already set Root Directory as `backend`, use this setup instead:

- Root Directory: `backend`
- Build Command: `npm run build`
- Start Command: `npm start`
- Health Check Path: `/health`

Environment variables. The base64 option is recommended on Render because it avoids private-key newline issues:

```text
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_SERVICE_ACCOUNT_BASE64=base64-encoded-full-service-account-json
FCM_RELAY_DRY_RUN=false
```

PowerShell command to create the base64 value from a downloaded key file:

```powershell
[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((Get-Content .\firebase-service-account.json -Raw)))
```

If you use `FIREBASE_SERVICE_ACCOUNT_JSON` instead, it must be the full downloaded JSON and must include:

- `project_id`
- `client_email`
- `private_key`

## Railway Setup

Create a new service from this repository:

- Root Directory: `backend/fcm-relay`
- Start Command: `npm start`

Add the same environment variables listed above.

## Outbox Format

The app already writes documents like:

```json
{
  "title": "New Leave Request",
  "body": "Employee requests leave on 2026-05-31",
  "topics": ["admin_all"],
  "type": "leave_request",
  "employeeId": "EMP001",
  "date": "2026-05-31",
  "status": "pending"
}
```

Supported delivery fields:

- `topics`: FCM topics such as `admin_all`, `team_all`, `team_tech`
- `recipientUid`: one Firebase Auth uid
- `recipientUids`: multiple Firebase Auth uids

For direct user delivery, the app must have saved device tokens in:

```text
fcm_tokens/{uid_platform}
```

## Status Values

The relay updates `fcm_outbox/{messageId}`:

- `processing`
- `sent`
- `failed`
- `retry`

If sending fails, the document becomes `retry` and the listener will attempt it again.

## Retry & Metrics (new)

The relay supports configurable retry/backoff and optional simple metrics. New environment variables:

- `FCM_MAX_RETRY_ATTEMPTS` (default `5`) — maximum retry attempts before marking a job `failed`.
- `FCM_BACKOFF_BASE_SECONDS` (default `30`) — base backoff in seconds; retries use exponential backoff (`base * 2^(retryCount-1)`).
- `FCM_BACKOFF_MAX_SECONDS` (default `86400`) — maximum backoff in seconds (defaults to 24 hours).
- `FCM_METRICS_ENABLED` (default `false`) — when `true`, the relay will write simple counters to Firestore under `fcm_metrics/summary` (`messagesAttempted`, `messagesSent`).

These are optional — if not set, the relay uses sensible defaults and continues working as before.

## Attendance App APIs

All API endpoints accept JSON and use `BACKEND_API_KEY` when configured. Send it as:

```text
x-api-key: your-private-api-key
```

### Teams

```http
GET /api/teams
POST /api/teams
GET /api/teams/:teamId/employees
```

### One-time migration from root collections

Your older app data may exist at root collections such as `employee_profiles`, `attendance`, `leave_requests`, and `salary_records`. Run this once to copy those documents into `Attendance/main/{collectionName}`:

```http
POST /api/admin/migrate-root-to-attendance
```

Optional body to migrate only selected collections:

```json
{
  "collections": ["users", "employee_profiles", "attendance", "leave_requests", "salary_records"]
}
```

Without `collections`, the backend copies all known attendance app collections.

Create/update team:

```json
{
  "teamId": "TECH",
  "name": "TECH",
  "description": "Engineering team",
  "logoPath": "attendance-app/teams/TECH/logo.png",
  "active": true
}
```

### Employees

```http
GET /api/employees/:employeeId
POST /api/employees
```

Create/update employee profile:

```json
{
  "employeeId": "EMP001",
  "uid": "firebase-auth-uid",
  "employeeName": "John Doe",
  "email": "john@company.com",
  "teamId": "TECH",
  "designation": "DEVELOPER",
  "monthlySalary": 45000,
  "joiningDate": "2026-06-01",
  "status": "active"
}
```

### Attendance

```http
POST /api/attendance/check-in
POST /api/attendance/check-out
GET /api/attendance?employeeId=EMP001&monthKey=2026-06
GET /api/attendance?teamId=TECH&date=2026-06-02
POST /api/attendance/close-day
```

Check in:

```json
{
  "employeeId": "EMP001",
  "at": "2026-06-02T09:30:00+05:30",
  "source": "mobile"
}
```

Check out:

```json
{
  "employeeId": "EMP001",
  "at": "2026-06-02T18:15:00+05:30"
}
```

Close missing attendance for a day:

```json
{
  "date": "2026-06-02",
  "status": "Absent"
}
```

### Salary

```http
POST /api/salary-structures
POST /api/salary/generate-month
POST /api/payroll/upload
GET /api/payroll/:employeeId/:monthKey
```

Salary structure:

```json
{
  "employeeId": "EMP001",
  "monthlySalary": 45000,
  "basicPay": 30000,
  "allowances": { "fixed": 10000 },
  "deductions": { "fixed": 2500 },
  "effectiveFrom": "2026-06"
}
```

Generate monthly salary records:

```json
{
  "year": 2026,
  "month": 6,
  "teamId": "TECH",
  "workingDays": 26,
  "notify": true
}
```

### Notifications and FCM

```http
POST /api/notifications/send
POST /api/fcm/send
```

Send to teams:

```json
{
  "title": "Announcement",
  "body": "Meeting at 5 PM",
  "targetType": "teams",
  "targetTeams": ["TECH", "OPERATIONS"],
  "senderRole": "admin",
  "senderName": "Admin",
  "type": "Announcement"
}
```

Send to one employee by employee id:

```json
{
  "title": "Salary Generated",
  "body": "Your salary slip is ready.",
  "targetType": "employee",
  "employeeId": "EMP001",
  "senderRole": "admin",
  "senderName": "Payroll",
  "type": "salary_generated"
}
```

Send to admin users:

```json
{
  "title": "Leave Request",
  "body": "EMP001 requested leave.",
  "targetType": "admin",
  "employeeId": "EMP001",
  "type": "leave_request"
}
```

The backend writes both:

```text
notifications/{notificationId}
team_messages/{messageId}
fcm_outbox/{messageId}
```

Then the relay listener sends FCM and updates `fcm_outbox.status`.

## Legacy Payroll API

Admin web payroll upload can call:

```http
POST /api/payroll/upload
```

JSON body:

```json
{
  "employeeId": "EMP001",
  "employeeName": "Employee Name",
  "department": "TECH",
  "role": "DEVELOPER",
  "year": 2026,
  "month": 6,
  "baseSalary": 24500,
  "grossSalary": 24500,
  "deductions": 0,
  "netSalary": 24500,
  "payableDays": 26,
  "officeMinutes": 10920,
  "leaveDays": 0,
  "notConsideredDays": 0,
  "notes": "June salary"
}
```

Optional environment variable:

```text
BACKEND_API_KEY=your-private-api-key
```

If `BACKEND_API_KEY` is set, requests must include:

```text
x-api-key: your-private-api-key
```

## Notes

- Never place Firebase service account JSON inside the Flutter app.
- Never commit service account JSON to git.
- FCM background and terminated delivery requires this relay to be running continuously.
- If the relay sleeps on a free hosting tier, pushes may be delayed until it wakes.
