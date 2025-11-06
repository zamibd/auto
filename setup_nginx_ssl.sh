#!/usr/bin/env bash
set -euo pipefail

# Re-run as root if needed
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "[i] Root privileges required — re-running with sudo..."
  exec sudo -E bash "$0" "$@"
fi

# Pretty log helpers
hr() { printf '%*s\n' "${COLUMNS:-80}" '' | tr ' ' '-'; }
ok() { echo -e "✅ $*"; }
info() { echo -e "ℹ️  $*"; }
err() { echo -e "❌ $*" >&2; }

trap 'err \"An error occurred. Check the logs above.\"; exit 1' ERR

hr
echo "Nginx + Let's Encrypt (Ubuntu 24.04) automated setup starting..."
hr

# 1) Update & Upgrade
info "Updating package lists and upgrading system..."
apt update && apt upgrade -y
ok "System update/upgrade done."

# 2) Install Nginx
info "Installing Nginx..."
apt install -y nginx
ok "Nginx installed."

# Start/enable/status
info "Starting and enabling Nginx service..."
systemctl start nginx
systemctl enable nginx
NGINX_ACTIVE="$(systemctl is-active nginx || true)"
systemctl --no-pager --full status nginx | sed -n '1,10p' || true
[[ "$NGINX_ACTIVE" == "active" ]] && ok "Nginx is running." || err "Nginx is not running!"

# 3) Install Certbot
info "Installing Certbot and Nginx plugin..."
apt install -y certbot python3-certbot-nginx
ok "Certbot installed."

# 4) Ask for domain & email; write nginx server block
echo
read -rp "Enter your domain (e.g., example.com): " DOMAIN
DOMAIN="${DOMAIN,,}"  # lowercase
if [[ -z "${DOMAIN}" ]]; then
  err "Domain cannot be empty."; exit 1
fi

read -rp "Enter your email for Let's Encrypt (e.g., admin@example.com): " EMAIL
if [[ -z "${EMAIL}" ]]; then
  err "Email cannot be empty."; exit 1
fi

SITE_AVAIL="/etc/nginx/sites-available/${DOMAIN}"
SITE_ENABLED="/etc/nginx/sites-enabled/${DOMAIN}"

info "Creating Nginx site config: ${SITE_AVAIL}"

cat > "${SITE_AVAIL}" <<EOF
server {
    listen 80;
    server_name ${DOMAIN} www.${DOMAIN};

    root /var/www/html;
    index index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

# Enable site (symlink)
ln -sfn "${SITE_AVAIL}" "${SITE_ENABLED}"

# Test & reload Nginx
info "Testing Nginx configuration..."
nginx -t
info "Reloading Nginx..."
systemctl reload nginx
ok "Nginx site ${DOMAIN} enabled."

# 5) Issue Let's Encrypt certificate (NON-INTERACTIVE)
echo
info "Requesting Let's Encrypt SSL (non-interactive) for ${DOMAIN} and www.${DOMAIN}..."
certbot --nginx \
  -d "${DOMAIN}" -d "www.${DOMAIN}" \
  --agree-tos -m "${EMAIL}" --redirect --no-eff-email \
  --non-interactive
ok "SSL deployment completed."

# 6) Check certbot.timer and dry-run renewal
info "Checking certbot.timer status..."
systemctl --no-pager --full status certbot.timer | sed -n '1,20p' || true

info "Testing renewal (dry-run)..."
certbot renew --dry-run
ok "Renewal dry-run succeeded."

# Pull versions
NGINX_VER="$(nginx -v 2>&1 | sed 's|nginx version: ||')"
CERTBOT_VER="$(certbot --version 2>/dev/null || true)"
OPENSSL_VER="$(openssl version 2>/dev/null || true)"

hr
echo "🎉 All set! HTTPS should now be live:"
echo "   https://${DOMAIN}"
echo "   https://www.${DOMAIN}"
hr
echo "Key paths:"
echo "  - Site config: ${SITE_AVAIL}"
echo "  - Enabled symlink: ${SITE_ENABLED}"
echo "  - SSL certs (symlinked): /etc/letsencrypt/live/${DOMAIN}/"
echo "      * fullchain.pem  -> Nginx ssl_certificate"
echo "      * privkey.pem    -> Nginx ssl_certificate_key"
hr
echo "Quick verify (from server):"
echo "  - nginx -t"
echo "  - systemctl status nginx"
echo "  - openssl x509 -in /etc/letsencrypt/live/${DOMAIN}/fullchain.pem -noout -dates"
hr
echo "Versions:"
echo "  - ${NGINX_VER}"
echo "  - ${CERTBOT_VER}"
echo "  - ${OPENSSL_VER}"
hr
ok "Deployment script completed successfully."
