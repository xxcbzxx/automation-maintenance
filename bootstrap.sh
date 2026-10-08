#!/bin/bash

set -euo pipefail

REPO="https://raw.githubusercontent.com/xxcbzxx/automation-maintenance/main"

log() {
    echo "[BOOTSTRAP] $*"
}

fail() {
    echo "[BOOTSTRAP][ERROR] $*" >&2
    exit 1
}

if [[ $EUID -ne 0 ]]; then
    fail "Run as root"
fi

log "Installing required packages"

apt-get update -qq

apt-get install -y \
    curl \
    yq

log "Creating directories"

mkdir -p /etc/n8n-maintenance

log "Downloading policy"

curl -fsSL \
    "${REPO}/command.yml?$(date +%s)" \
    -o /etc/n8n-maintenance/policy.yml

log "Downloading scripts"

curl -fsSL \
    "${REPO}/scripts/n8n-maintenance?$(date +%s)" \
    -o /usr/local/sbin/n8n-maintenance

curl -fsSL \
    "${REPO}/scripts/n8n-policy-sync?$(date +%s)" \
    -o /usr/local/sbin/n8n-policy-sync

log "Downloading systemd units"

curl -fsSL \
    "${REPO}/systemd/n8n-policy-sync.service?$(date +%s)" \
    -o /etc/systemd/system/n8n-policy-sync.service

curl -fsSL \
    "${REPO}/systemd/n8n-policy-sync.timer?$(date +%s)" \
    -o /etc/systemd/system/n8n-policy-sync.timer

log "Setting ownership"

chown root:root \
    /etc/n8n-maintenance/policy.yml \
    /usr/local/sbin/n8n-maintenance \
    /usr/local/sbin/n8n-policy-sync \
    /etc/systemd/system/n8n-policy-sync.service \
    /etc/systemd/system/n8n-policy-sync.timer

chmod 0644 \
    /etc/n8n-maintenance/policy.yml

chmod 0755 \
    /usr/local/sbin/n8n-maintenance \
    /usr/local/sbin/n8n-policy-sync

log "Creating sudoers rule"

HOSTNAME_SHORT="$(hostname -s)"

cat > /etc/sudoers.d/n8n-maintenance <<EOF
${HOSTNAME_SHORT} ALL=(root) NOPASSWD: /usr/local/sbin/n8n-maintenance check, /usr/local/sbin/n8n-maintenance patch, /usr/local/sbin/n8n-maintenance reboot, /usr/local/sbin/n8n-maintenance health
EOF

chmod 0440 /etc/sudoers.d/n8n-maintenance
chown root:root /etc/sudoers.d/n8n-maintenance

visudo -cf /etc/sudoers.d/n8n-maintenance >/dev/null

log "Reloading systemd"

systemctl daemon-reload

log "Enabling policy sync timer"

systemctl enable --now n8n-policy-sync.timer

log "Running initial policy sync"

systemctl start n8n-policy-sync.service

log "Running validation"

sudo -n /usr/local/sbin/n8n-maintenance check

sudo -n /usr/local/sbin/n8n-maintenance health

log "Bootstrap completed successfully"

echo
echo "Hostname: $(hostname)"
echo "Policy:   /etc/n8n-maintenance/policy.yml"
echo "Timer:    n8n-policy-sync.timer"
echo
