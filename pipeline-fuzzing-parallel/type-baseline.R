#!/usr/bin/env Rscript

output_dir <- "data/baseline-types"
traces_file <- commandArgs(trailingOnly = TRUE)[1]
types <- signatr::traces_type(traces_file, signatr:::type_system_tastr, "../data/db/cran_db-6")

if (length(types) == 0) {
    q(save = "no")
}

if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
}

types <- lapply(types, function(x) subset(x, select=c(fun_name, signature)))
types <- do.call(rbind, types)

qs::qsave(types, file.path(output_dir, basename(traces_file)))
