#!/usr/bin/env Rscript

fs <- list.files(path = "data/fuzz", recursive = FALSE, full.names = TRUE, include.dirs = FALSE)

pb <- progress::progress_bar$new(
    format = "  fixing :what [:bar] :percent eta: :eta",
    clear = FALSE, total = length(fs), width = 60
)

for (x in fs) {
    pb$tick(tokens = list(what = basename(x)))
    tryCatch(
        {
            df <- qs::qread(x)
            df <- dplyr::mutate(df, rdb_path = file.path("rdb", basename(x)))
            qs::qsave(df, x)
        },
        error = function(e) {
            message("Error while processing ", x, ": ", e$msg)
        }
    )
}
