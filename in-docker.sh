#!/bin/bash -x

DOCKER_IMAGE_NAME="prlprg/project-signatr"

R_PROJECT_BASE_DIR="/mnt/nvme1/R/project-signatR"
CRAN_DIR="$R_PROJECT_BASE_DIR/CRAN"
LIBRARY_DIR="$R_PROJECT_BASE_DIR/library/4.0"

LOCAL_DIR="$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )"
LOCAL_LIBRARY_DIR="$LOCAL_DIR/library"

cmd="bash"
[ $# -gt 0 ] && cmd="$@"

[ -d "$LOCAL_LIBRARY_DIR" ] || mkdir -p "$LOCAL_LIBRARY_DIR"

docker run \
    -ti \
    --rm \
    -v "$CRAN_DIR:/R/CRAN:ro" \
    -v "$LIBRARY_DIR:/R/library:ro" \
    -v "$LOCAL_DIR:/home/r/work" \
    -e R_LIBS="/home/r/work/library:/R/library" \
    -e USER_ID=$(id -u) \
    -e USER_GID=$(id -g) \
    -w "/home/r/work" \
    "$DOCKER_IMAGE_NAME" \
    $cmd

# docker run \
#     --rm \
#     -v "$local_working_dir:$DOCKER_working_dir" \
#     "$DOCKER_IMAGE_NAME" \
#     chown -R $(id -u):$(id -g) "$docker_working_dir"
