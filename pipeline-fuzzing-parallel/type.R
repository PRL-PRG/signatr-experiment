#!/usr/bin/env Rscript

traces_file <- commandArgs(trailingOnly = TRUE)[1]
types <- signatr::traces_type(traces_file, signatr:::type_system_tastr, "../data/db/cran_db-6")

if (length(types) > 0) {
    qs::qsave(types, file.path("data/types", basename(traces_file)))
}
