#!/usr/bin/env bash
# One-time setup of OpenReply on ServerPoint. Run as root on the server:
#
#   git clone -b drnisa-serverpoint https://github.com/ekayum/openreply.git /opt/openreply
#   cd /opt/openreply/deploy/serverpoint && bash setup.sh
#
# Writes .env with fresh secrets (only if .env does not exist yet), opens
# ports 80/443, then builds and starts the stack. Re-running is safe.
set -euo pipefail
cd "$(dirname "$0")"

DOMAIN="${OPENREPLY_DOMAIN:-go.drnisakhalil.com}"

if [ ! -f .env ]; then
  read -rp "Email(s) allowed to sign in (comma separated): " ALLOWED
  read -rsp "Resend API key (re_...): " RESEND; echo
  read -rp "Sender [OpenReply <onboarding@resend.dev>]: " FROM
  FROM="${FROM:-OpenReply <onboarding@resend.dev>}"
  umask 077
  cat > .env <<EOF
OPENREPLY_DOMAIN=${DOMAIN}
NEXTAUTH_URL=https://${DOMAIN}
NEXTAUTH_SECRET=$(openssl rand -hex 32)
CRON_SECRET=$(openssl rand -hex 32)
ENCRYPTION_KEY=$(openssl rand -hex 32)
POSTGRES_PASSWORD=$(openssl rand -hex 24)
RESEND_API_KEY=${RESEND}
EMAIL_FROM=${FROM}
ALLOWED_EMAILS=${ALLOWED}
META_GRAPH_API_VERSION=v25.0
EOF
  echo "Wrote .env (mode 600). Back it up: losing ENCRYPTION_KEY means reconnecting Zernio."
fi

SERVER_IP=$(curl -s4 https://ifconfig.me || true)
if ! getent hosts "$DOMAIN" | grep -q "$SERVER_IP"; then
  echo "WARNING: $DOMAIN does not resolve to this server ($SERVER_IP) yet. Caddy cannot get a certificate until it does."
fi

ufw allow 80/tcp >/dev/null
ufw allow 443/tcp >/dev/null

docker compose up -d --build
docker compose ps
echo "Check: curl -s https://${DOMAIN}/api/health"
