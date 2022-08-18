#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(dplyr))
library(stringr)
library(covr)

coverage <- function(traces, args_db) {
    if (nrow(traces) == 0) {
        return(
            tibble(filename = character(0), functions = character(0), line = integer(0), value = integer(0))
        )
    }

    fun_name <- traces$fun_name[1]
    fun <- str_replace(fun_name, ".*::(.*)", "\\1")
    pkg <- str_replace(fun_name, "(.*)::.*", "\\1")

    code <- sapply(
        traces$args_idx,
        function(args_idx) {
            args <- sapply(args_idx, function(x) str_glue("sxpdb::get_value_idx(args_db, {x})"))
            args <- paste0(args, collapse = ", ")
            # str_glue("tryCatch({fun_name}({args}), error=function(e) message(e$msg), finally=pb$tick())")
            str_glue("tryCatch({fun_name}({args}), error=function(e) message(e$msg))")
        }
    )

    code <- paste0(code, collapse = "\n")

    code <- parse(text = code)

    # pb <- progress::progress_bar$new(
    #     format = "  coverage [:bar] :percent eta: :eta",
    #     clear = FALSE, total = length(traces$args_idx)
    # )

    covr <- tryCatch(
        {
            res <- covr::function_coverage(fun, code, getNamespace(pkg))
            covr::tally_coverage(res)
        },
        error = function(e) {
            message("Coverage failed: ", e$message)
            tibble(filename = character(0), functions = character(0), line = integer(0), value = integer(0))
        }
    )
}

# traces
args <- commandArgs(TRUE)
input <- args[1]
output <- args[2]
args_db <- args[3]

traces <- signatr::traces_load(input)

covr <-
    traces %>%
    filter(status == 0) %>%
    group_by(fun_name) %>%
    do(coverage(., sxpdb::open_db(args_db))) %>%
    mutate(input = input)

qs::qsave(covr, output)
