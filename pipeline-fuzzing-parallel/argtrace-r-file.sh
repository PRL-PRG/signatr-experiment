#!/bin/bash

export LANGUAGE=en
export LC_COLLATE=C
export LC_TIME=C
export LC_ALL=C
export SRCDIR=.
export R_TESTS=""
export R_BROWSER=false
export R_PDFVIEWER=false
export R_KEEP_PKG_SOURCE=yes
export R_KEEP_PKG_PARSE_DATA=yes
export RUNR_CWD="$(pwd)"
unset R_LIBS_SITE
unset R_LIBS_USER

export R_LIBS=$(readlink -f ../pipeline-fuzzing/out/library)

cwd="$(pwd)"
file=$(basename "$1")
dir=$(dirname "$1")
path=$(realpath "$1")

OUTPUT=$(readlink -f data/baseline)
SXPDB=$(readlink -f $OUTPUT/$file.sxpdb)

[[ -d "$SXPDB" ]] && rm -fr "$SXPDB"

cd "$dir"

/usr/bin/time -f '%x,%e,%M,%P' \
  R --no-save --no-echo --quiet --no-readline -e "argtracer::trace_file('$file', '$OUTPUT/$file.sxpdb', '$OUTPUT/$file.callids')"
