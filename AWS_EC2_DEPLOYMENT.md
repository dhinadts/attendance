# AWS EC2 Deployment Guide

Product name: **DhinaDTS WorkforceOps**

Production URL:

```text
https://workforce.dhinadts.com/
```

Backend public prefix:

```text
https://workforce.dhinadts.com/p1/
```

`/api/` is intentionally not used because it is already reserved by the existing `dhinadts.com` website stack.

## Why This Name

**DhinaDTS WorkforceOps** is the recommended product name because this system is broader than attendance. It covers face attendance, geofence tracking, tasks, leave approvals, payroll, notifications, and audit workflows.

## Route 53

Create this record in the `dhinadts.com` hosted zone:

| Record | Type | Value |
| --- | --- | --- |
| `workforce.dhinadts.com` | A | EC2 Elastic IP |

Use an Elastic IP for the EC2 instance so DNS does not break on restart.

## EC2 Security Group

Allow inbound:

| Port | Source | Purpose |
| --- | --- | --- |
| 22 | Your admin IP only | SSH |
| 80 | `0.0.0.0/0`, `::/0` | HTTP and Certbot challenge |
| 443 | `0.0.0.0/0`, `::/0` | HTTPS |

Do not expose backend port `8080`. Nginx proxies `/p1/` to `127.0.0.1:8080/api/`.

## Run On EC2

Copy the deployment script to EC2:

```bash
scp -i /path/to/key.pem deploy/ec2/make-workforceops-live.sh ubuntu@your-ec2-public-ip:/tmp/
ssh -i /path/to/key.pem ubuntu@your-ec2-public-ip
```

Run it once to create the backend env file:

```bash
sudo DOMAIN=workforce.dhinadts.com \
  ENABLE_SSL=false \
  bash /tmp/make-workforceops-live.sh
```

Edit the generated env file:

```bash
sudo nano /etc/dhinadts-workforce/backend.env
```

Required values:

```bash
PORT=8080
FIREBASE_PROJECT_ID=inmakes-87ea0
FIREBASE_SERVICE_ACCOUNT_BASE64=base64-encoded-service-account-json
BACKEND_API_KEY=replace-with-long-random-private-key
ALLOW_UNAUTHENTICATED_BACKEND_API=false
FCM_RELAY_DRY_RUN=false
FCM_METRICS_ENABLED=true
FIRESTORE_APP_ROOT_COLLECTION=Attendance
FIRESTORE_APP_ROOT_DOCUMENT=main
```

Run again after editing env:

```bash
sudo DOMAIN=workforce.dhinadts.com \
  ENABLE_SSL=false \
  bash /tmp/make-workforceops-live.sh
```

After Route 53 resolves correctly to EC2, enable HTTPS:

```bash
sudo DOMAIN=workforce.dhinadts.com \
  SSL_EMAIL=admin@dhinadts.com \
  ENABLE_SSL=true \
  bash /tmp/make-workforceops-live.sh
```

## Verify

```bash
curl https://workforce.dhinadts.com/
curl https://workforce.dhinadts.com/health
curl -H "x-api-key: your-backend-api-key" https://workforce.dhinadts.com/p1/relay/status
```

Expected Nginx behavior:

- `/` serves Flutter web.
- `/p1/*` proxies to the WorkforceOps backend.
- `/health` proxies to backend health.
- Flutter browser routes fall back to `/index.html`.
- Static assets are cached; service worker and manifest are not aggressively cached.

## Production Checklist

- Route 53 `workforce.dhinadts.com` A record points to EC2 Elastic IP.
- EC2 security group allows 80 and 443.
- `/api/` remains untouched for the existing website stack.
- `/p1/relay/status` rejects without API key and succeeds with API key.
- PM2 process `dhinadts-workforce-api` is online.
- `sudo nginx -t` passes.
- Certbot certificate is issued for `workforce.dhinadts.com`.
- Firestore rules are deployed separately.
- Camera and GPS behavior is tested on real devices.
