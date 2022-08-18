#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(dplyr))

callids_file <- commandArgs(trailingOnly = TRUE)[1]
baseline_file <- tools::file_path_sans_ext(callids_file)
callids <- readr::read_csv(callids_file, col_names = c("cid", "pkg", "fun", "param", "vid"))
corpus <- readr::read_csv("data/corpus.csv")
callids <- semi_join(callids, corpus, by = c("pkg" = "pkg_name", "fun" = "fun_name"))

if (nrow(callids) == 0) {
    q(save = "no")
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
        rdb_path = paste0(baseline_file, ".sxpdb")
    ) %>%
    ungroup() %>%
    select(-pkg, -fun) %>%
    rename(id = cid)

qs::qsave(traces, file.path("data/baseline-traces", basename(baseline_file)))
