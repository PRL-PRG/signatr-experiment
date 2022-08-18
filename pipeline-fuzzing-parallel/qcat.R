#!/usr/bin/env Rscript

print(tibble::as_tibble(qs::qread(commandArgs(trailingOnly = TRUE)[1])), n = Inf)
