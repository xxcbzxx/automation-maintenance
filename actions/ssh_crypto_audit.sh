#!/bin/bash

TARGET="${1:-localhost}"

docker run --rm \
docker.io/positronsecurity/ssh-audit \
-j "$TARGET"
