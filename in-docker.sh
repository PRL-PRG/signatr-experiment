#!/bin/bash

if [ $# -eq 0 ]; then
    echo "Usage: $0 args"
    exit 1
fi

BASE_DIR=$(dirname "$0")
R_LIBS=$(readlink -e $BASE_DIR/library)

exec make shell R_LIBS="$R_LIBS" SHELL_CMD="$*"
