#!/bin/bash

echo "===PATCH==="

if ! /usr/local/sbin/n8n-patch; then
    echo "===MAINTENANCE_RESULT==="
    echo "STATUS=ERROR"
    echo "ACTION=patch"
    exit 1
fi

echo "===MAINTENANCE_RESULT==="
echo "STATUS=SUCCESS"
echo "ACTION=patch"
