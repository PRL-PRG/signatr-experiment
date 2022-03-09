library(tarchetypes)
library(targets)
library(tibble)
library(future)
library(future.callr)
library(generatr)
library(dplyr)


# TODO: move to utils
create_dir <- function(...) {
    p <- file.path(...)
    if (!dir.exists(p)) stopifnot(dir.create(p, recursive = TRUE))
    p
}

R_ENVIR <- c(
    callr::rcmd_safe_env(),
    "R_KEEP_PKG_SOURCE" = 1,
    "R_ENABLE_JIT" = 0,
    "R_COMPILE_PKGS" = 0,
    "R_DISABLE_BYTECODE" = 1
)

# maximum time allowed for a program to run in seconds
TIMEOUT <- 5 * 60
OUT_DIR <- Sys.getenv("OUT_DIR", "out")
LIB_DIR <- Sys.getenv("LIB_DIR", file.path(OUT_DIR, "library"))
DB_DIR <- Sys.getenv("DB_DIR", "/mnt/ocfs_vol_00/cran_db-3/")
BUDGET <- 10e3

# packages to test
CORPUS <- c("stringr")

tar_option_set(
    packages = c("dplyr", "generatr", "runr", "sxpdb"),
)

plan(callr)

print(OUT_DIR)
print(LIB_DIR)
print(DB_DIR)

lib_dir <- create_dir(LIB_DIR)

library(sxpdb)

list(
    tar_target(
        packages_bin,
        {
            runr::install_cran_packages(
                CORPUS,
                lib_dir,
                dependencies = TRUE,
                check = FALSE
            ) %>% pull(dir)
        },
        format = "file",
        deployment = "main"
    ),
    tar_target(
        packages,
        {
            package <- basename(packages_bin)
            version <- sapply(package, function(x) as.character(packageVersion(x, lib.loc = lib_dir)))
            tibble(package, version)
        }
    ),
    tar_target(
        functions,
        {
            runr::metadata_functions(packages$package) %>%
                filter(exported, !is_s3_dispatch, !is_s3_method)
        },
        pattern = map(packages)
    ),
    tar_target(
        functions_,
        dplyr::bind_rows(functions)
    ),
    tar_target(
        origins_db,
        {
            value_db <- sxpdb::open_db(DB_DIR)
            sxpdb::view_origins_db(value_db) %>%
                as_tibble
        }
    ),
    tar_target(
        meta_db,
        {
            value_db <- sxpdb::open_db(DB_DIR)
            sxpdb::view_meta_db(value_db) %>%
                as_tibble
        }
    ),
    tar_target(
        fuzz,
        {
            value_db <- sxpdb::open_db(DB_DIR)
            fun <- get(functions_$fun_name, envir = getNamespace(functions_$pkg_name), mode = "function")
            generatr::feedback_directed_call_generator_all_db(
                fn = fun,
                functions_$pkg_name,
                functions_$fun_name,
                value_db,
                origins_db,
                meta_db,
                budget = BUDGET
            )
        },
        pattern = map(functions_)
    )
    # tar_target(
    #     programs_metadata,
    #     {
    #         output_dir <- file.path(programs_dir, packages$package)
    #         sloc <- cloc(output_dir, by_file = TRUE, r_only = TRUE) %>%
    #             select(file = filename, code)
    #         res <- tibble(file = programs_files, package = packages$package, type = basename(dirname(file)))
    #         left_join(res, sloc, by = "file")
    #     },
    #     pattern = map(packages)
    # )
    # tar_target(
    #     programs_trace,
    #     {
    #         pkg_argtracer
    #         tmp_db <- tempfile(fileext = ".sxpdb")
    #         file <- normalizePath(programs_files_)
    #         withr::defer(unlink(tmp_db, recursive = TRUE))
    #         tryCatch(
    #             callr::r(
    #                 function(...) argtracer::trace_file(...),
    #                 list(file, tmp_db),
    #                 libpath = normalizePath(lib_dir),
    #                 show = TRUE,
    #                 wd = dirname(file),
    #                 env = R_ENVIR,
    #                 timeout = TIMEOUT
    #             ),
    #             error = function(e) {
    #                 data.frame(status = -2, time = NA, file = file,
    #                            db_path = NA, db_size = NA, error = e$message)
    #             }
    #         )
    #     },
    #     pattern = map(programs_files_)
    # ),
    # tar_render(report, "report.Rmd")
)
