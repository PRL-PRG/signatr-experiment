#!/bin/bash

OUTPUT=data/baseline-coverage
INPUT=data/baseline

mkdir -p "$OUTPUT"

export R_LIBS=../pipeline-fuzzing/out/library

find $INPUT -maxdepth 1 -name '*.traces' | \
  parallel \
    --results "$OUTPUT/run.csv" \
    --jobs 64 \
    --bar \
    ./coverage.R '{1}' "$OUTPUT/{1/.}.coverage" "$INPUT/{1/.}.sxpdb"
