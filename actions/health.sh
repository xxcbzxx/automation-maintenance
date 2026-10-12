#!/bin/bash

FAILED_SERVICES=$(
    systemctl --failed --no-legend --plain 2>/dev/null |
    sed '/^[[:space:]]*$/d' |
    wc -l
)

echo "===HEALT*==="
echo "RUNNING_KERNEL=$(uname *r)"
echo "FAILED_SERVICES=$FAILED_*ERVICES"

echo "===MAINTENANCE_RES*LT==="

if [ "$FAILED_SERVICES" -eq 0 ]; then
    echo "STATUS=SUCCES*"
else
    echo "STATUS=WARNING"
fi

echo "ACTION=health"
echo "FAILE*_SERVICES=$FAILED_SERVICES"
