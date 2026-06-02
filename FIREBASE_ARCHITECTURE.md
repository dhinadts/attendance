# Attendance App Firebase Architecture

This architecture keeps Firestore scalable while still allowing the UI to display data as:

```text
Attendance App
└─ Teams
   └─ Users
      └─ Date
         └─ Attendance
```

Do not physically nest Firestore as `teams/{team}/users/{user}/dates/{date}/attendance`. This app uses one root namespace document, then flat subcollections with `teamId`, `employeeId`, `date`, and `monthKey` fields. This keeps queries and indexes predictable for 100+ teams, 10,000+ employees, and multi-year history.

Physical Firestore namespace:

```text
Attendance/main
├─ users
├─ teams
├─ employee_profiles
├─ attendance
├─ attendance_records
├─ leave_requests
├─ notifications
├─ team_messages
├─ fcm_outbox
├─ salary_records
└─ salary_structures
```

## Firestore Collections

```text
Attendance/main/users/{uid}
Attendance/main/teams/{teamId}
Attendance/main/employee_profiles/{employeeId}
Attendance/main/attendance_records/{employeeId_YYYY-MM-DD}
Attendance/main/attendance_summaries/{employeeId_YYYY-MM}
Attendance/main/team_attendance_summaries/{teamId_YYYY-MM}
Attendance/main/leave_requests/{requestId}
Attendance/main/salary_structures/{employeeId}
Attendance/main/salary_records/{employeeId_YYYY-MM}
Attendance/main/notifications/{notificationId}
Attendance/main/notification_reads/{uid_notificationId}
Attendance/main/fcm_tokens/{uid_deviceId}
Attendance/main/fcm_outbox/{notificationId}
Attendance/main/announcements/{announcementId}
Attendance/main/company_documents/{documentId}
Attendance/main/holidays/{dateKey}
Attendance/main/audit_logs/{logId}
```

Current app compatibility collections such as `attendance`, `team_messages`, and `notification_inbox` can remain during migration. New features should prefer the canonical collections above.

## Document Examples

### `users/{uid}`

```json
{
  "uid": "firebase-auth-uid",
  "email": "employee@company.com",
  "role": "EMPLOYEE",
  "employeeId": "EMP001",
  "teamId": "TECH",
  "active": true,
  "createdAt": "serverTimestamp"
}
```

### `teams/{teamId}`

```json
{
  "teamId": "TECH",
  "name": "TECH",
  "logoPath": "attendance-app/teams/TECH/logo.png",
  "active": true,
  "createdAt": "serverTimestamp"
}
```

### `employee_profiles/{employeeId}`

```json
{
  "employeeId": "EMP001",
  "uid": "firebase-auth-uid",
  "employeeName": "John Doe",
  "designation": "DEVELOPER",
  "teamId": "TECH",
  "department": "TECH",
  "email": "john@company.com",
  "monthlySalary": 45000,
  "profilePhotoPath": "attendance-app/users/EMP001/profile/profile.jpg",
  "joiningDate": "2026-01-10",
  "status": "active"
}
```

### `attendance_records/{employeeId_YYYY-MM-DD}`

```json
{
  "employeeId": "EMP001",
  "uid": "firebase-auth-uid",
  "teamId": "TECH",
  "date": "2026-06-02",
  "monthKey": "2026-06",
  "checkInAt": "2026-06-02T09:30:00+05:30",
  "checkOutAt": "2026-06-02T18:15:00+05:30",
  "workMinutes": 525,
  "status": "Present",
  "attachments": [
    "attendance-app/attendance/2026/06/02/TECH/EMP001/checkin.jpg"
  ],
  "createdAt": "serverTimestamp",
  "updatedAt": "serverTimestamp"
}
```

Supported attendance statuses:

```text
Present
Absent
Leave
Half Day
Holiday
Weekend
```

### `attendance_summaries/{employeeId_YYYY-MM}`

```json
{
  "employeeId": "EMP001",
  "teamId": "TECH",
  "monthKey": "2026-06",
  "presentDays": 22,
  "absentDays": 1,
  "leaveDays": 1,
  "halfDays": 0,
  "holidayDays": 1,
  "weekendDays": 4,
  "totalWorkMinutes": 10560,
  "updatedAt": "serverTimestamp"
}
```

### `salary_structures/{employeeId}`

```json
{
  "employeeId": "EMP001",
  "teamId": "TECH",
  "monthlySalary": 45000,
  "basicPay": 30000,
  "allowances": {
    "hra": 8000,
    "travel": 2000
  },
  "deductions": {
    "pf": 1800,
    "tax": 700
  },
  "effectiveFrom": "2026-06",
  "active": true
}
```

### `salary_records/{employeeId_YYYY-MM}`

```json
{
  "employeeId": "EMP001",
  "teamId": "TECH",
  "monthKey": "2026-06",
  "basicPay": 30000,
  "allowances": 10000,
  "deductions": 2500,
  "netSalary": 37500,
  "payableDays": 24,
  "salarySlipPath": "attendance-app/salary-slips/2026-06/TECH/EMP001/slip.pdf",
  "generatedAt": "serverTimestamp"
}
```

### `notifications/{notificationId}`

```json
{
  "title": "Salary Generated",
  "body": "Your June salary slip is ready.",
  "type": "Salary Generated",
  "targetType": "employee",
  "recipientUid": "firebase-auth-uid",
  "employeeId": "EMP001",
  "teamId": "TECH",
  "route": "/notifications",
  "createdAt": "serverTimestamp",
  "data": {
    "salaryRecordId": "EMP001_2026-06"
  }
}
```

## Firebase Storage Hierarchy

```text
attendance-app/
├─ users/
│  └─ EMP001/
│     ├─ profile/profile.jpg
│     ├─ documents/id-proof.pdf
│     └─ attendance/2026/06/02/attachment.jpg
├─ teams/
│  └─ TECH/logo.png
├─ attendance/
│  └─ 2026/06/02/TECH/EMP001/checkin.jpg
├─ leave-documents/
│  └─ 2026/06/EMP001/leave-request-001.pdf
├─ salary-slips/
│  └─ 2026-06/TECH/EMP001/slip.pdf
├─ announcements/
│  └─ 2026/announcement-001/file.pdf
└─ company-documents/
   └─ policies/attendance-policy.pdf
```

Rules are defined in `storage.rules` and deployed via `firebase.json`.

## Query Patterns

Employee attendance by month:

```text
attendance_records
where employeeId == EMP001
where monthKey == 2026-06
```

Team attendance by date:

```text
attendance_records
where teamId == TECH
where date == 2026-06-02
```

Team attendance by month:

```text
attendance_records
where teamId == TECH
where monthKey == 2026-06
```

Employee salary history:

```text
salary_records
where employeeId == EMP001
orderBy monthKey desc
```

Notifications for employee:

```text
notifications
where recipientUid == uid
orderBy createdAt desc
```

Notifications for team:

```text
notifications
where teamId == TECH
orderBy createdAt desc
```

## Cloud Functions / Backend Jobs

Use either Firebase Cloud Functions or the Node relay in `backend/fcm-relay`.

Recommended jobs:

```text
scheduledAttendanceReminder
  - Finds employees without today's check-in.
  - Writes notifications and FCM outbox entries.

scheduledDailyAttendanceClose
  - Marks missing attendance as Absent, Weekend, or Holiday.
  - Updates attendance_summaries and team_attendance_summaries.

onLeaveRequestUpdated
  - Sends Leave Approval notifications.
  - Updates attendance_records when leave is approved.

monthlySalaryGeneration
  - Reads attendance_summaries and salary_structures.
  - Writes salary_records.
  - Generates salary slip metadata/path.
  - Sends Salary Generated notification.

onNotificationCreated
  - Resolves recipients by uid/team/topic.
  - Sends FCM.
  - Updates notification delivery status.
```

The relay API can queue a push through:

```http
POST /api/fcm/send
```

Body:

```json
{
  "title": "Announcement",
  "body": "Meeting at 5 PM",
  "targetType": "teams",
  "targetTeams": ["TECH"],
  "topics": ["team_tech"],
  "senderRole": "admin",
  "senderName": "Admin",
  "type": "Announcement"
}
```

## Indexes

Indexes are defined in `firestore.indexes.json` and wired in `firebase.json`.

Primary composites:

```text
attendance_records: employeeId + date desc
attendance_records: teamId + date desc
attendance_records: employeeId + monthKey
attendance_records: teamId + monthKey
salary_records: employeeId + monthKey desc
salary_records: teamId + monthKey desc
notifications: recipientUid + createdAt desc
notifications: employeeId + createdAt desc
notifications: teamId + createdAt desc
leave_requests: teamId + status + createdAt desc
```

## Dart Model Sketches

```dart
class AttendanceRecord {
  const AttendanceRecord({
    required this.employeeId,
    required this.teamId,
    required this.date,
    required this.monthKey,
    required this.status,
    this.checkInAt,
    this.checkOutAt,
    this.workMinutes = 0,
  });

  final String employeeId;
  final String teamId;
  final String date;
  final String monthKey;
  final String status;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final int workMinutes;
}

class SalaryRecord {
  const SalaryRecord({
    required this.employeeId,
    required this.teamId,
    required this.monthKey,
    required this.basicPay,
    required this.allowances,
    required this.deductions,
    required this.netSalary,
  });

  final String employeeId;
  final String teamId;
  final String monthKey;
  final num basicPay;
  final num allowances;
  final num deductions;
  final num netSalary;
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.recipientUid,
    this.employeeId,
    this.teamId,
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime createdAt;
  final String? recipientUid;
  final String? employeeId;
  final String? teamId;
}
```
