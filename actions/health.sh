#!/bin/bash

FAILED_SERVICES=$(
    systemctl --failed --no-legend --plain 2>/dev/null |
    sed '/^[[:space:]]*$/d' |
    wc -l
)

echo "===HEALTH==="
echo "RUNNING_KERNEL=$(uname -r)"
echo "FAILED_SERVICES=$FAILED_SERVICES"

echo "===MAINTENANCE_RESULT==="

if [ "$FAILED_SERVICES" -eq 0 ]; then
    echo "STATUS=SUCCESS"
else
    echo "STATUS=WARNING"
fi

echo "ACTION=health"
echo "FAILED_SERVICES=$FAILED_SERVICES"
