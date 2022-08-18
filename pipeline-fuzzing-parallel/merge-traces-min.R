#!/usr/bin/env Rscript

library(data.table)

fs <- list.files(path = "data/fuzz", recursive = FALSE, full.names = TRUE, include.dirs = FALSE)
fs <- fs[!dir.exists(fs)]

pb <- progress::progress_bar$new(
    format = "  reading :what [:bar] :percent eta: :eta",
    clear = FALSE, total = length(fs)
)

df <- NULL

for (x in fs) {
    pb$tick(tokens = list(what = basename(x)))
    r <- qs::qread(x)
    r <- subset(r, select = -c(args_idx, dispatch))
    df <- data.table::rbindlist(list(df, r), use.names = FALSE)
}

message("Saving...")

qs::qsave(df, "data/all-traces-min.qs")
