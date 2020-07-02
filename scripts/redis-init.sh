#!/bin/bash -ex
DOCKER=${DOCKER:-`which docker 2>/dev/null || which podman 2>/dev/null`}
IMG=docker.io/redis

${DOCKER} pull ${IMG}
${DOCKER} run -d -p 6379:6379 ${IMG}
