#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${DOMAIN:-workforce.dhinadts.com}"
REPO_URL="${REPO_URL:-https://github.com/dhinadts/attendance.git}"
BRANCH="${BRANCH:-main}"
APP_NAME="${APP_NAME:-dhinadts-workforce}"
APP_DIR="${APP_DIR:-/opt/${APP_NAME}/source}"
WEB_ROOT="${WEB_ROOT:-/var/www/${APP_NAME}/current}"
ENV_FILE="${ENV_FILE:-/etc/${APP_NAME}/backend.env}"
BACKEND_PORT="${BACKEND_PORT:-8080}"
PM2_APP_NAME="${PM2_APP_NAME:-${APP_NAME}-api}"
SSL_EMAIL="${SSL_EMAIL:-admin@dhinadts.com}"
ENABLE_SSL="${ENABLE_SSL:-false}"
FLUTTER_VERSION="${FLUTTER_VERSION:-stable}"

if [ "$(id -u)" -ne 0 ]; then
  echo "Run on EC2 with sudo: sudo bash make-workforceops-live.sh"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y nginx git curl ca-certificates gnupg unzip xz-utils zip rsync

if ! command -v node >/dev/null 2>&1; then
  install -d -m 0755 /etc/apt/keyrings
  if [ ! -f /etc/apt/keyrings/nodesource.gpg ]; then
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
      | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
  fi
  echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" \
    > /etc/apt/sources.list.d/nodesource.list
  apt-get update
  apt-get install -y nodejs
fi

if ! command -v pm2 >/dev/null 2>&1; then
  npm install -g pm2
fi

if [ ! -d /opt/flutter ]; then
  git clone https://github.com/flutter/flutter.git -b "$FLUTTER_VERSION" /opt/flutter
fi
git -C /opt/flutter fetch --depth 1 origin "$FLUTTER_VERSION"
git -C /opt/flutter checkout "$FLUTTER_VERSION"
export PATH="/opt/flutter/bin:$PATH"
flutter config --enable-web
flutter doctor || true

mkdir -p "$(dirname "$APP_DIR")" "$WEB_ROOT" "$(dirname "$ENV_FILE")"
if [ ! -d "$APP_DIR/.git" ]; then
  git clone -b "$BRANCH" "$REPO_URL" "$APP_DIR"
else
  git -C "$APP_DIR" fetch origin "$BRANCH"
  git -C "$APP_DIR" checkout "$BRANCH"
  git -C "$APP_DIR" pull --ff-only origin "$BRANCH"
fi

if [ ! -f "$ENV_FILE" ]; then
  cat >"$ENV_FILE" <<ENV
PORT=${BACKEND_PORT}
FIREBASE_PROJECT_ID=inmakes-87ea0
FIREBASE_SERVICE_ACCOUNT_BASE64=REPLACE_WITH_BASE64_SERVICE_ACCOUNT_JSON
BACKEND_API_KEY=REPLACE_WITH_LONG_RANDOM_PRIVATE_KEY
ALLOW_UNAUTHENTICATED_BACKEND_API=false
FCM_RELAY_DRY_RUN=false
FCM_METRICS_ENABLED=true
FIRESTORE_APP_ROOT_COLLECTION=Attendance
FIRESTORE_APP_ROOT_DOCUMENT=main
ENV
  chmod 600 "$ENV_FILE"
  echo "Created $ENV_FILE. Edit Firebase service account and BACKEND_API_KEY, then run this script again."
  exit 2
fi

set -a
. "$ENV_FILE"
set +a

if [ -z "${BACKEND_API_KEY:-}" ] || [[ "${BACKEND_API_KEY}" == REPLACE_* ]]; then
  echo "BACKEND_API_KEY is not configured in $ENV_FILE."
  exit 3
fi
if { [ -z "${FIREBASE_SERVICE_ACCOUNT_BASE64:-}" ] || [[ "${FIREBASE_SERVICE_ACCOUNT_BASE64}" == REPLACE_* ]]; } \
  && [ -z "${FIREBASE_SERVICE_ACCOUNT_JSON:-}" ]; then
  echo "Firebase service account is not configured in $ENV_FILE."
  exit 3
fi

cd "$APP_DIR"
npm --prefix backend/fcm-relay ci --omit=dev
npm --prefix backend run check

flutter pub get
flutter analyze
flutter test
flutter build web --release --base-href / \
  --dart-define=ATTENDANCE_API_BASE_URL="https://${DOMAIN}/p1" \
  --dart-define=ATTENDANCE_API_KEY="${BACKEND_API_KEY}" \
  --dart-define=PAYROLL_API_BASE_URL="https://${DOMAIN}/p1" \
  --dart-define=PAYROLL_API_KEY="${BACKEND_API_KEY}"

rsync -a --delete build/web/ "$WEB_ROOT/"
chown -R www-data:www-data "/var/www/${APP_NAME}"

cat >"/etc/nginx/sites-available/${APP_NAME}.conf" <<NGINX
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    root ${WEB_ROOT};
    index index.html;
    client_max_body_size 20m;

    location /p1/ {
        proxy_pass http://127.0.0.1:${BACKEND_PORT}/api/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 120s;
    }

    location /health {
        proxy_pass http://127.0.0.1:${BACKEND_PORT}/health;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location ~* \.(?:js|css|png|jpg|jpeg|gif|ico|svg|webp|woff2?)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
        try_files \$uri =404;
    }

    location = /flutter_service_worker.js {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        try_files \$uri =404;
    }

    location = /manifest.json {
        add_header Cache-Control "no-cache";
        try_files \$uri =404;
    }
}
NGINX

ln -sfn "/etc/nginx/sites-available/${APP_NAME}.conf" "/etc/nginx/sites-enabled/${APP_NAME}.conf"
nginx -t
systemctl enable nginx
systemctl reload nginx

cd "$APP_DIR/backend/fcm-relay"
pm2 start src/index.js --name "$PM2_APP_NAME" --update-env || pm2 restart "$PM2_APP_NAME" --update-env
pm2 save
pm2 startup systemd -u root --hp /root >/dev/null || true

if [ "$ENABLE_SSL" = "true" ]; then
  apt-get install -y certbot python3-certbot-nginx
  certbot --nginx --non-interactive --agree-tos --redirect \
    --email "$SSL_EMAIL" \
    -d "$DOMAIN"
fi

echo "DhinaDTS WorkforceOps is deployed."
echo "Frontend: https://${DOMAIN}/"
echo "Backend public prefix: https://${DOMAIN}/p1/"
echo "Health: https://${DOMAIN}/health"
