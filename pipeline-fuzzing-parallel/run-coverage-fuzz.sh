#!/bin/bash

OUTPUT=data/fuzz-coverage
INPUT=data/fuzz

mkdir -p "$OUTPUT"

export R_LIBS=../pipeline-fuzzing/out/library

find $INPUT -maxdepth 1 -name "*::*" | \
  parallel \
    --results "$OUTPUT/run.csv" \
    --jobs 64 \
    --bar \
    ./coverage.R '{1}' "$OUTPUT/{1/.}.coverage" "../data/db/cran_db-6"
