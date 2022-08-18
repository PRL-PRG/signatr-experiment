#!/usr/bin/env Rscript

do_fuzz <- function(pkg_name, fun_name,
                    db_path, origins_db, lib_loc, rdb_path,
                    budget_runs, budget_time_s, timeout_one_call_ms,
                    quiet) {
    value_db <- sxpdb::open_db(db_path)
    generator <- generatr::create_fd_args_generator(
        pkg_name,
        fun_name,
        value_db,
        origins_db,
        meta_db = NULL,
        budget = budget_runs,
        lib_loc = lib_loc
    )
    runner <- generatr::runner_start(lib_loc = lib_loc, quiet = quiet)
    withr::defer(generatr::runner_stop(runner), envir = runner)
    runner_fun <- generatr::create_fuzz_runner(db_path, runner, timeout_ms = timeout_one_call_ms)

    if (!dir.exists(dirname(rdb_path))) {
        dir.create(dirname(rdb_path))
    }
    rdb <- sxpdb::open_db(rdb_path, mode = TRUE)
    on.exit(sxpdb::close_db(rdb))
    processor <- generatr::store_result(rdb)

    res <- generatr::fuzz(
        pkg_name,
        fun_name,
        generator = generator,
        runner = runner_fun,
        result_processor = processor,
        quiet = quiet,
        timeout_s = budget_time_s
    )

    cbind(
        res,
        fun_name = paste0(pkg_name, "::", fun_name),
        rdb_path = rdb_path
    )
}

args <- commandArgs(trailingOnly = TRUE)
pkg_name <- args[1]
fun_name <- args[2]
budget_runs <- if (is.null(args[3])) {
    5000
} else {
    as.integer(args[3])
}

fun <- paste0(pkg_name, "::", gsub("/", "__div__", fun_name, fixed = TRUE))

base_dir <- normalizePath(".", mustWork = TRUE)

db_path <- file.path(base_dir, "../data/db/cran_db-6")
origins_path <- file.path(base_dir, paste0("data/origins/", fun))
lib_loc <- file.path(base_dir, "../pipeline-fuzzing/out/library")
lib_loc <- c(lib_loc, .libPaths())
rdb_path <- file.path(base_dir, paste0("data/rdb/", fun))
budget_time_s <- 60 * 60
timeout_one_call_ms <- 60 * 1000
quiet <- FALSE
output <- file.path(base_dir, paste0("data/fuzz/", fun))

origins <- tryCatch({
    qs::qread(origins_path)
}, error = function(e) {
    qs::qread(file.path(base_dir, "../data/db/empty-origins.qs"))
})

if (dir.exists(rdb_path)) {
    message("RDB already exists, removing: ", rdb_path)
    unlink(rdb_path, recursive = TRUE)
}

# poor man's sandboxing
tmp <- tempfile()
dir.create(tmp)
setwd(tmp)

res <- do_fuzz(
    pkg_name, fun_name,
    db_path, origins, lib_loc, rdb_path,
    budget_runs, budget_time_s, timeout_one_call_ms,
    quiet
)

res[, "rdb_path"] <- sub(file.path(base_dir, "data/rdb/"), "../rdb/", res[, "rdb_path"], fixed = TRUE)

print(res)

qs::qsave(res, output)
