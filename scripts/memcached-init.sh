#!/bin/bash -ex
DOCKER=${DOCKER:-`which docker 2>/dev/null || which podman 2>/dev/null`}
IMG=docker.io/memcached

${DOCKER} pull ${IMG}
${DOCKER} run -d -p 11211:11211 ${IMG}
