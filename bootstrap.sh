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
mkdir -p /etc/n8n-maintenance/actions

chmod 0755 /etc/n8n-maintenance/actions

log "Downloading policy"

curl -fsSL \
    -H 'Cache-Control: no-cache' \
    "${REPO}/command.yml?$(date +%s)" \
    -o /etc/n8n-maintenance/policy.yml

log "Downloading actions manifest"

curl -fsSL \
    -H 'Cache-Control: no-cache' \
    "${REPO}/actions.yml?$(date +%s)" \
    -o /etc/n8n-maintenance/actions.yml

[ -s /etc/n8n-maintenance/actions.yml ] ||
    fail "actions.yml is empty"

yq '.' /etc/n8n-maintenance/actions.yml >/dev/null ||
    fail "Invalid actions.yml"

log "Downloading scripts"

curl -fsSL \
    "${REPO}/scripts/n8n-maintenance?$(date +%s)" \
    -o /usr/local/sbin/n8n-maintenance

curl -fsSL \
    "${REPO}/scripts/n8n-policy-sync?$(date +%s)" \
    -o /usr/local/sbin/n8n-policy-sync

log "Downloading actions"

while IFS= read -r ACTION_FILE; do
echo "[BOOTSTRAP] Downloading action ${ACTION_FILE}"
    curl -fsSL \
    "${REPO}/actions/${ACTION_FILE}?$(date +%s)" \
    -o "/etc/n8n-maintenance/actions/${ACTION_FILE}" ||
    fail "Failed downloading action ${ACTION_FILE}"

    [ -s "/etc/n8n-maintenance/actions/${ACTION_FILE}" ] ||
        fail "Downloaded action ${ACTION_FILE} is empty"

    bash -n "/etc/n8n-maintenance/actions/${ACTION_FILE}" ||
        fail "Syntax validation failed for ${ACTION_FILE}"

done < <(
    yq -r '.actions[]' /etc/n8n-maintenance/actions.yml
)

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
    /etc/n8n-maintenance/actions.yml \
    /usr/local/sbin/n8n-maintenance \
    /usr/local/sbin/n8n-policy-sync \
    /etc/systemd/system/n8n-policy-sync.service \
    /etc/systemd/system/n8n-policy-sync.timer

chown root:root \
    /etc/n8n-maintenance/actions/* \
    2>/dev/null || true

chmod 0644 \
    /etc/n8n-maintenance/policy.yml \
    /etc/n8n-maintenance/actions.yml

chmod 0755 \
    /usr/local/sbin/n8n-maintenance \
    /usr/local/sbin/n8n-policy-sync

chmod 0755 \
    /etc/n8n-maintenance/actions/* \
    2>/dev/null || true

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
echo "Actions:     /etc/n8n-maintenance/actions"
echo "Dispatcher:  /usr/local/sbin/n8n-maintenance"
echo "Sync Script: /usr/local/sbin/n8n-policy-sync"
echo "Timer:       n8n-policy-sync.timer"
echo

echo "Legacy sudoers backup location:"
echo "${BACKUP_DIR:-None}"

echo

echo "Current Policy:"
echo "  Policy Enabled : $(yq -r '.policy.enabled' /etc/n8n-maintenance/policy.yml)"
echo "  Patch Enabled  : $(yq -r '.allowed_actions.patch.enabled // false' /etc/n8n-maintenance/policy.yml)"
echo "  Reboot Enabled : $(yq -r '.allowed_actions.reboot.enabled // false' /etc/n8n-maintenance/policy.yml)"
echo
