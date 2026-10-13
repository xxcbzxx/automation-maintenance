#!/bin/bash

set -euo pipefail

HOSTNAME=$(hostname)
TIMESTAMP=$(date -Iseconds)

SSHD_T=$(sshd -T 2>/dev/null || true)

get_setting() {
    local key="$1"
    echo "$SSHD_T" | awk -v k="$key" '$1==k {print $2}' | head -1
}

bool_json() {
    case "${1:-}" in
        yes|true|active|enabled)
            echo "true"
            ;;
        *)
            echo "false"
            ;;
    esac
}

SERVICE_ACTIVE=$(systemctl is-active ssh 2>/dev/null || echo inactive)
SERVICE_ENABLED=$(systemctl is-enabled ssh 2>/dev/null || echo disabled)

PASSWORDAUTH=$(get_setting passwordauthentication)
PUBKEYAUTH=$(get_setting pubkeyauthentication)
PERMITROOTLOGIN=$(get_setting permitrootlogin)
PERMITEMPTYPASSWORDS=$(get_setting permitemptypasswords)
KBDINTERACTIVE=$(get_setting kbdinteractiveauthentication)
USEPAM=$(get_setting usepam)

X11FORWARDING=$(get_setting x11forwarding)
ALLOWTCPFORWARDING=$(get_setting allowtcpforwarding)

MAXAUTHTRIES=$(get_setting maxauthtries)
LOGINGRACETIME=$(get_setting logingracetime)

CLIENTALIVEINTERVAL=$(get_setting clientaliveinterval)
CLIENTALIVECOUNTMAX=$(get_setting clientalivecountmax)

ALLOWUSERS=$(echo "$SSHD_T" | awk '$1=="allowusers" {$1=""; sub(/^ /,""); print}')
ALLOWGROUPS=$(echo "$SSHD_T" | awk '$1=="allowgroups" {$1=""; sub(/^ /,""); print}')
DENYUSERS=$(echo "$SSHD_T" | awk '$1=="denyusers" {$1=""; sub(/^ /,""); print}')
DENYGROUPS=$(echo "$SSHD_T" | awk '$1=="denygroups" {$1=""; sub(/^ /,""); print}')

SSH_PORT=$(get_setting port)

if [ -z "${SSH_PORT:-}" ]; then
    SSH_PORT="22"
fi

ALLOWED_SOURCES=""

if command -v iptables-save >/dev/null 2>&1; then
    ALLOWED_SOURCES=$(iptables-save 2>/dev/null | \
        grep -- "--dport $SSH_PORT" | \
        grep '\-s ' | \
        sed -n 's/.*-s \([^ ]*\).*/\1/p' | \
        sort -u)
fi

if [ -z "$ALLOWED_SOURCES" ] && command -v nft >/dev/null 2>&1; then
    ALLOWED_SOURCES=$(nft list ruleset 2>/dev/null | \
        grep "$SSH_PORT" | \
        grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+' | \
        sort -u)
fi

FIREWALL_RESTRICTED=false
JUMPHOST_ONLY=false

if [ -n "$ALLOWED_SOURCES" ]; then
    FIREWALL_RESTRICTED=true

    if [ "$(echo "$ALLOWED_SOURCES" | wc -l)" -eq 1 ]; then
        ONLY_SOURCE=$(echo "$ALLOWED_SOURCES")

        if [ "$ONLY_SOURCE" = "192.168.1.124/32" ]; then
            JUMPHOST_ONLY=true
        fi
    fi
fi

ALLOWED_SOURCES_JSON=$(printf '%s\n' "$ALLOWED_SOURCES" | \
    sed '/^$/d' | \
    awk '{printf "\"%s\",\n",$0}' | \
    sed '$ s/,$//')

cat <<EOF
{
  "hostname": "$HOSTNAME",
  "timestamp": "$TIMESTAMP",
  "ssh": {
    "service_active": $(bool_json "$SERVICE_ACTIVE"),
    "service_enabled": $(bool_json "$SERVICE_ENABLED"),

    "port": "$SSH_PORT",

    "passwordauthentication": "$PASSWORDAUTH",
    "pubkeyauthentication": "$PUBKEYAUTH",
    "permitrootlogin": "$PERMITROOTLOGIN",
    "permitemptypasswords": "$PERMITEMPTYPASSWORDS",
    "kbdinteractiveauthentication": "$KBDINTERACTIVE",
    "usepam": "$USEPAM",

    "x11forwarding": "$X11FORWARDING",
    "allowtcpforwarding": "$ALLOWTCPFORWARDING",

    "maxauthtries": "$MAXAUTHTRIES",
    "logingracetime": "$LOGINGRACETIME",

    "clientaliveinterval": "$CLIENTALIVEINTERVAL",
    "clientalivecountmax": "$CLIENTALIVECOUNTMAX",

    "allowusers": "$ALLOWUSERS",
    "allowgroups": "$ALLOWGROUPS",
    "denyusers": "$DENYUSERS",
    "denygroups": "$DENYGROUPS"
  },

  "firewall": {
    "restricted": $FIREWALL_RESTRICTED,
    "jumphost_only": $JUMPHOST_ONLY,
    "allowed_sources": [
      $ALLOWED_SOURCES_JSON
    ]
  }
}
EOF
