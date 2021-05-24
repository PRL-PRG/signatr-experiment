#!/bin/bash -x

DOCKER_IMAGE_NAME="prlprg/project-signatr"

R_PROJECT_BASE_DIR="$PWD"
CRAN_DIR="$R_PROJECT_BASE_DIR/CRAN"
LIBRARY_DIR="$R_PROJECT_BASE_DIR/library/4.0"

cmd="bash"
[ $# -gt 0 ] && cmd="$@"

docker run \
    -ti \
    --rm \
    -v "$PWD:$PWD" \
    -e R_LIBS="$PWD/library" \
    -e USER_ID=$(id -u) \
    -e USER_GID=$(id -g) \
    -w "$PWD" \
    "$DOCKER_IMAGE_NAME" \
    $cmd
