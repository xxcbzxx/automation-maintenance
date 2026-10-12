#!/bin/bash

CONTAINER=$(docker ps \
  --filter "label=com.docker.swarm.service.name=dav-n8n_dav-n8n" \
  --format '{{.ID}}' |
  head -1)

if [ -z "$CONTAINER" ]; then
    echo "===MAINTENANCE_RESULT==="
    echo "STATUS=ERROR"
    echo "ACTION=dav_n8n_version"
    echo "ERROR=CONTAINER_NOT_FOUND"
    exit 1
fi

N8N_VERSION=$(
    docker exec "$CONTAINER" n8n --version
)

echo "===MAINTENANCE_RESULT==="
echo "STATUS=SUCCESS"
echo "ACTION=dav_n8n_version"
echo "N8N_VERSION=${N8N_VERSION}"
