#!/bin/bash

OUTPUT=data/baseline
CODE=../data/extracted-code

mkdir -p "$OUTPUT"

./find-runnable-code.R | \
  parallel \
    --results "$OUTPUT/run.csv" \
    --jobs 64 \
    --bar \
    ./argtrace-r-file.sh '{1}'
