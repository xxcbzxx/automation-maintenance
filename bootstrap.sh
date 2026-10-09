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

HOSTNAME_SHORT="$(hostname -s)"

log "Installing required packages"

apt-get update -qq
apt-get install -y curl yq

echo
echo "========================================="
echo "Existing sudoers files"
echo "========================================="

ls -la /etc/sudoers.d/

echo

BACKUP_DIR="/root/bootstrap-backups/sudoers.d/$(date +%Y%m%d-%H%M%S)"

mkdir -p "$BACKUP_DIR"

MOVED_FILES=0

for file in /etc/sudoers.d/*; do

    [ -f "$file" ] || continue

    name="$(basename "$file")"

    case "$name" in
        README|n8n-maintenance)
            continue
            ;;
    esac

    echo "[BACKUP] Moving $file"

    mv "$file" "$BACKUP_DIR/"

    MOVED_FILES=$((MOVED_FILES + 1))

done

if [ "$MOVED_FILES" -gt 0 ]; then
    echo
    echo "[BOOTSTRAP] Existing sudoers files moved to:"
    echo "  $BACKUP_DIR"
    echo
else
    rmdir "$BACKUP_DIR" 2>/dev/null || true
fi 
log "Creating directories"

mkdir -p /etc/n8n-maintenance

log "Downloading policy"

curl -fsSL \
    -H 'Cache-Control: no-cache' \
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

chmod 0644 /etc/n8n-maintenance/policy.yml

chmod 0755 \
    /usr/local/sbin/n8n-maintenance \
    /usr/local/sbin/n8n-policy-sync

log "Creating sudoers rule"

cat > /etc/sudoers.d/n8n-maintenance <<EOF
${HOSTNAME_SHORT} ALL=(root) NOPASSWD: /usr/local/sbin/n8n-maintenance
EOF

chmod 0440 /etc/sudoers.d/n8n-maintenance
chown root:root /etc/sudoers.d/n8n-maintenance

log "Validating sudoers"

visudo -cf /etc/sudoers.d/n8n-maintenance >/dev/null

log "Reloading systemd"

systemctl daemon-reload

log "Enabling timer"

systemctl enable --now n8n-policy-sync.timer

log "Initial sync"

systemctl start n8n-policy-sync.service

log "Validation"

sudo -n /usr/local/sbin/n8n-maintenance check
sudo -n /usr/local/sbin/n8n-maintenance health

echo
echo "========================================="
echo "Bootstrap completed successfully"
echo "========================================="
echo

echo "Host:        $(hostname)"
echo "Policy:      /etc/n8n-maintenance/policy.yml"
echo "Dispatcher:  /usr/local/sbin/n8n-maintenance"
echo "Sync Script: /usr/local/sbin/n8n-policy-sync"
echo "Timer:       n8n-policy-sync.timer"
echo
echo "Legacy sudoers backup location:"
echo "${BACKUP_DIR:-None}"
echo
echo "Current Policy:"
echo "  Policy Enabled : $(yq -r '.policy.enabled' /etc/n8n-maintenance/policy.yml)"
echo "  Patch Enabled  : $(yq -r '.allowed_actions.patch.enabled' /etc/n8n-maintenance/policy.yml)"
echo "  Reboot Enabled : $(yq -r '.allowed_actions.reboot.enabled' /etc/n8n-maintenance/policy.yml)"
echo
