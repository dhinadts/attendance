# attendance FCM Relay

Standalone Node backend for sending Firebase Cloud Messaging push notifications without Firebase Cloud Functions.

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

Environment variables:

```text
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_SERVICE_ACCOUNT_JSON={...full service account json...}
FCM_RELAY_DRY_RUN=false
```

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

## Notes

- Never place Firebase service account JSON inside the Flutter app.
- Never commit service account JSON to git.
- FCM background and terminated delivery requires this relay to be running continuously.
- If the relay sleeps on a free hosting tier, pushes may be delayed until it wakes.
