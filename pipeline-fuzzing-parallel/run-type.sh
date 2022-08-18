#!/bin/bash

OUTPUT=data/types
INPUT=data/fuzz

mkdir -p "$OUTPUT"

filter() {
  while read -r line; do
    if [[ ! -f "$OUTPUT/$(basename $line)" ]]; then
      echo $line
    fi
  done
}

find $INPUT -type f -maxdepth 1 | \
  filter | \
  parallel \
    --results "$OUTPUT/run.csv" \
    --jobs 64 \
    --bar \
    ./type.R '{1}'
