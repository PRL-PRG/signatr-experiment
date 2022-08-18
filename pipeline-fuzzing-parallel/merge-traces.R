#!/usr/bin/env Rscript

fs <- list.files(path = "data/fuzz", recursive = FALSE, full.names = TRUE, include.dirs = FALSE)
fs <- fs[!dir.exists(fs)]

pb <- progress::progress_bar$new(
    format = "  reading :what [:bar] :percent eta: :eta",
    clear = FALSE, total = length(fs)
)

traces <- purrr::map_dfr(fs, ~ {
    pb$tick(tokens = list(what = basename(.)))
    qs::qread(.)
})

message("Saving...")

qs::qsave(traces, "data/all-traces.qs")
