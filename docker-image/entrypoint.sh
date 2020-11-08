#!/bin/bash
set -e

USER="r"
USER_ID=${USER_ID:-1000}
GROUP="r"
GROUP_ID=${USER_ID:-1000}

groupmod -g ${GROUP_ID} ${GROUP}
usermod -u ${USER_ID} -g ${GROUP_ID} ${USER}

exec sudo -u r \
     HOME="/home/r" \
     PATH="$PATH" \
     R_LIBS="$R_LIBS" \
     IN_DOCKER=1 \
     OMP_NUM_THREADS=$OMP_NUM_THREADS \
     R_COMPILE_PKGS=$R_COMPILE_PKGS \
     R_DISABLE_BYTECODE=$R_DISABLE_BYTECODE \
     R_ENABLE_JIT=$R_ENABLE_JIT \
     R_KEEP_PKG_SOURCE=$R_KEEP_PKG_SOURCE \
     "$@"
