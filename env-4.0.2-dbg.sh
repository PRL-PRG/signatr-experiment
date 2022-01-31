R_BIN=$(readlink -e R-4.0.2-dbg/bin)

export PATH=$R_BIN:$PATH
export R_LIBS=$(readlink -m library-local)

[ -d "$R_LIBS" ] || mkdir -p "$R_LIBS"
