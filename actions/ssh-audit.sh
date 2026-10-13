#!/bin/bash

set -euo pipefail

HOSTNAME=$(hostname)
TIMESTAMP=$(date -Iseconds)

get_bool() {
    local value="$1"

    case "$value" in
        yes|true|active|enabled)
            echo "true"
            ;;
        *)
            echo "false"
            ;;
    esac
}

SSH_ACTIVE=$(systemctl is-active ssh 2>/dev/null || echo inactive)
SSH_ENABLED=$(systemctl is-enabled ssh 2>/dev/null || echo disabled)

PASSWORD_AUTH=$(sshd -T 2>/dev/null | awk '/^passwordauthentication/ {print $2}')
ROOT_LOGIN=$(sshd -T 2>/dev/null | awk '/^permitrootlogin/ {print $2}')
PUBKEY_AUTH=$(sshd -T 2>/dev/null | awk '/^pubkeyauthentication/ {print $2}')
EMPTY_PASSWORDS=$(sshd -T 2>/dev/null | awk '/^permitemptypasswords/ {print $2}')
KBD_AUTH=$(sshd -T 2>/dev/null | awk '/^kbdinteractiveauthentication/ {print $2}')

SSH_VERSION=$(ssh -V 2>&1)

PORTS=$(ss -ltn 2>/dev/null | grep sshd | awk '{print $4}' | sed 's/.*://' | sort -u | paste -sd "," -)

FAILED_LOGINS=$(lastb 2>/dev/null | grep -vc '^btmp begins' || echo 0)

AUTH_KEYS=0

while read -r file; do
    if [ -f "$file" ]; then
        COUNT=$(grep -cv '^$' "$file" 2>/dev/null || echo 0)
        AUTH_KEYS=$((AUTH_KEYS + COUNT))
    fi
done < <(find /root /home -name authorized_keys 2>/dev/null)

ALLOWED_SOURCES=$(iptables-save 2>/dev/null | \
    grep '\--dport 22' | \
    grep '\-s' | \
    sed -n 's/.*-s \([^ ]*\).*/"\1"/p' | \
    paste -sd "," -)

if [ -n "$ALLOWED_SOURCES" ]; then
    FIREWALL_RESTRICTED=true
else
    FIREWALL_RESTRICTED=false
    ALLOWED_SOURCES=""
fi

FAIL2BAN=false
if command -v fail2ban-client >/dev/null 2>&1; then
    FAIL2BAN=true
fi

SCORE=0

[ "$PASSWORD_AUTH" = "no" ] && SCORE=$((SCORE + 20))
[[ "$ROOT_LOGIN" == "no" || "$ROOT_LOGIN" == "prohibit-password" ]] && SCORE=$((SCORE + 15))
[ "$PUBKEY_AUTH" = "yes" ] && SCORE=$((SCORE + 10))
[ "$EMPTY_PASSWORDS" = "no" ] && SCORE=$((SCORE + 10))
[ "$FIREWALL_RESTRICTED" = true ] && SCORE=$((SCORE + 20))
[ "$FAIL2BAN" = true ] && SCORE=$((SCORE + 5))
[ "$FAILED_LOGINS" -eq 0 ] && SCORE=$((SCORE + 10))

if [ "$SCORE" -ge 95 ]; then
    GRADE="A"
elif [ "$SCORE" -ge 85 ]; then
    GRADE="B"
elif [ "$SCORE" -ge 70 ]; then
    GRADE="C"
else
    GRADE="D"
fi

cat <<EOF
{
  "hostname": "$HOSTNAME",
  "timestamp": "$TIMESTAMP",
  "ssh": {
    "service_active": $(get_bool "$SSH_ACTIVE"),
    "service_enabled": $(get_bool "$SSH_ENABLED"),
    "password_auth": $(get_bool "$PASSWORD_AUTH"),
    "root_login": "$ROOT_LOGIN",
    "pubkey_auth": $(get_bool "$PUBKEY_AUTH"),
    "empty_passwords": $(get_bool "$EMPTY_PASSWORDS"),
    "kbdinteractive_auth": $(get_bool "$KBD_AUTH"),
    "ports": "$PORTS",
    "authorized_keys": $AUTH_KEYS,
    "failed_logins": $FAILED_LOGINS,
    "firewall_restricted": $FIREWALL_RESTRICTED,
    "allowed_sources": [ $ALLOWED_SOURCES ],
    "fail2ban": $FAIL2BAN,
    "ssh_version": "$SSH_VERSION"
  },
  "score": $SCORE,
  "grade": "$GRADE"
}
EOF
