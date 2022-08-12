R_BIN=$(readlink -e R-dyntrace-ddb/bin)

export PATH=$R_BIN:$PATH
export R_LIBS=$(readlink -m library)
export R_KEEP_PKG_SOURCE=1
export R_ENABLE_JIT=0
export R_COMPILE_PKGS=0
export R_DISABLE_BYTECODE=1

[ -d "$R_LIBS" ] || mkdir -p "$R_LIBS"
