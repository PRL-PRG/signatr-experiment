#!/bin/bash

OUTPUT=data/baseline-types
INPUT=data/baseline

mkdir -p "$OUTPUT"

find $INPUT -maxdepth 1 -name '*.callids' | \
  parallel \
    --results "$OUTPUT/run.csv" \
    --jobs 64 \
    --bar \
    ./type-baseline.R '{1}'
