# Production QA Checklist

Date: 2026-06-08
Project: DhinaDTS Attendance / WorkSync Pro

Use this checklist before production rollout. Automated analysis and web builds are not enough for the items below because they depend on device hardware, operating-system permission behavior, or real production-length data.

## Device-Level Attendance Checks

### Camera and Face Attendance

- Test on at least one Android phone with a front camera.
- Test on one low-end Android device if available.
- Grant camera permission and confirm face scan opens, detects one face, and logs attendance.
- Deny camera permission and confirm the app shows a recoverable permission message.
- Test poor lighting, side angle, and multiple faces in frame.
- Confirm the attendance document stores face metadata/liveness signals without storing unnecessary sensitive image data.
- Confirm failed/spoof attempts do not mark attendance.

### Geolocation and Office Circle

Office location:

```text
Latitude: 11.3966658
Longitude: 77.8880424
Allowed radius: 50 meters
```

- Login inside 50 meters and confirm attendance starts normally.
- Try login outside 50 meters and confirm the attempt is logged as outside-office.
- Move outside 50 meters during an active session and confirm break tracking starts.
- Return within 30 minutes and confirm the session resumes as back-to-office.
- Return after 30 minutes and confirm the reason/request flow appears.
- Take multiple breaks in one day and confirm office minutes are accumulated correctly.
- Confirm eligibility requires at least 7 office-circle hours in the day.
- Lock the phone, background the app, reopen it, and confirm GPS reconciliation repairs the current inside/outside state.

## Navigation and Responsive Checks

### App Drawer After Public Pages

- Open Privacy Policy from Settings on mobile.
- Open Terms of Service from Settings on mobile.
- Open Support from Settings on mobile.
- Use the hamburger menu on each public page.
- Navigate back to Dashboard, Profile, Notifications, and Settings.
- Confirm the drawer closes cleanly after navigation and no back button replaces the hamburger.

### Long Real Data

Create or edit QA records with long values:

```text
Employee name: Demo Very Long Employee Name With Multiple Initials Kumar
Team name: Enterprise Software Development And Field Operations
Role label: Senior Principal Attendance Compliance Operations Coordinator
Employee code: DTS-EMP-2026-00000012345
```

- Check left drawer identity block.
- Check employee profile header and editable fields.
- Check admin profile cards.
- Check attendance log rows/cards.
- Check export filters and report output.
- Check notifications and message detail screens.
- Check mobile, tablet, and desktop widths.

## Backend Operations Checks

- Deploy the relay backend with `BACKEND_API_KEY` configured.
- Confirm `/health` returns HTTP 200.
- Confirm `/p1/relay/status` requires the API key and shows outbox counts.
- Send a test notification and confirm `fcm_outbox` changes from `pending` to `sent`.
- Force a bad token/topic test and confirm `retry` or `failed` is visible.
- Use `POST /p1/fcm-outbox/{messageId}/retry` after correcting the issue.
- Deploy Firestore rules from this repository and confirm employee attendance tamper attempts are rejected.
- Build Flutter web/mobile with `ATTENDANCE_API_BASE_URL` and `ATTENDANCE_API_KEY` before treating backend attendance finalization as authoritative.
