#!/bin/bash

echo "===UPDATES==="

apt list --upgradable 2>/dev/null |
    tail -n +2

UPDATE_COUNT=$(
    apt list --upgradable 2>/dev/null |
        tail -n +2 |
        sed '/^[[:space:]]*$/d' |
        wc -l
)

echo "===MAINTENANCE_RESULT==="
echo "STATUS=SUCCESS"
echo "ACTION=check"
echo "UPDATE_COUNT=${UPDATE_COUNT}"
``
