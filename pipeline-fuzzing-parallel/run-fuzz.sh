#!/bin/bash

BUDGET=5000
BASE_DIR=data/fuzz
CORPUS=${1:-data/corpus.csv}

xsv select -n 1,2 "$CORPUS" | \
  parallel \
    --sshloginfile cluster \
    --csv \
    --results "data/run-$(basename "$CORPUS")" \
    --jobs 64 \
    --bar \
    --env PATH \
    --env R_LIBS \
    --workdir $(pwd) \
    --basefile ./fuzz.R \
    --timeout 90m \
    /usr/bin/time -f '"%C",%x,%e,%M,%P' ./fuzz.R '{1}' '{2}' "$BUDGET"
