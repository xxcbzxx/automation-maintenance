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

LEGACY_FOUND=false

for file in \
    /etc/sudoers.d/n8n-patch \
    /etc/sudoers.d/n8n-inventory
do
    if [[ -f "$file" ]]; then
        echo "[FOUND] $file"
        LEGACY_FOUND=true
    fi
done

if [[ "$LEGACY_FOUND" == true ]]; then

    echo
    echo "Legacy sudoers files detected."
    echo
    echo "Choose:"
    echo "  K = Keep existing rules"
    echo "  R = Backup and remove legacy rules"
    echo "  A = Abort"
    echo

    read -rp "Selection [K/R/A]: " CHOICE

    case "${CHOICE^^}" in

        K)
            log "Keeping legacy sudoers files"
            ;;

        R)
            log "Backing up and removing legacy sudoers files"

            mkdir -p /root/bootstrap-backups

            for file in \
                /etc/sudoers.d/n8n-patch \
                /etc/sudoers.d/n8n-inventory
            do
                if [[ -f "$file" ]]; then

                    target="/root/bootstrap-backups/$(basename "$file").$(date +%s)"

                    cp "$file" "$target"

                    rm -f "$file"

                    echo "[BACKUP] $file -> $target"
                fi
            done
            ;;

        A)
            fail "Aborted by user"
            ;;

        *)
            fail "Invalid selection"
            ;;

    esac
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
echo "Host:    $(hostname)"
echo "Policy:  /etc/n8n-maintenance/policy
