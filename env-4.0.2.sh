R_BIN=$(readlink -e R-4.0.2/bin)

export PATH=$R_BIN:$PATH
export R_LIBS=$(readlink -m library)

[ -d "$R_LIBS" ] || mkdir -p "$R_LIBS"
