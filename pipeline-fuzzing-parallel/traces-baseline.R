#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(dplyr))

fs <- list.files("data/baseline", pattern = "\\.callids$", recursive = FALSE, full.names = TRUE)

corpus <- readr::read_csv("data/corpus.csv")

pb <- progress::progress_bar$new(
    format = "  reading :what [:bar] :percent eta: :eta",
    clear = FALSE, total = length(fs)
)

for (f in fs) {
    baseline_file <- tools::file_path_sans_ext(f)

    callids <- readr::read_csv(f, col_names = c("cid", "pkg", "fun", "param", "vid"), show_col_types = FALSE)
    callids <- semi_join(callids, corpus, by = c("pkg" = "pkg_name", "fun" = "fun_name"))

    if (nrow(callids) == 0) {
        next;
    }

    traces <- callids %>%
        group_by(cid, pkg, fun) %>%
        filter(!any(vid == -1)) %>%
        summarise(
            args_idx = {
                tmp <- as.integer(vid[-n()])
                names(tmp) <- param[-n()]
                list(tmp)
            },
            error = NA,
            exit = NA,
            status = 0,
            result = vid[n()],
            fun_name = paste0(pkg[1], "::", fun[1]),
            dispatch = list(list()),
            rdb_path = paste0(basename(baseline_file), ".sxpdb")
        ) %>%
        ungroup() %>%
        select(-pkg, -fun) %>%
        rename(id = cid)

    qs::qsave(traces, file.path("data/baseline", paste0(basename(baseline_file), ".traces")))

    pb$tick(tokens = list(what = basename(baseline_file)))
}
