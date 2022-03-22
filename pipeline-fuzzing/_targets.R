library(tarchetypes)
library(targets)
library(tibble)
library(future)
library(future.callr)
library(generatr)
library(dplyr)
library(withr)


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
DB_DIR <- Sys.getenv("DB_DIR", "/mnt/ocfs_vol_00/cran_db-5/")
BUDGET <- 3000

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
        run_existing,
        {
            # TODO: can the code be somehow shared between
            # run_existing / run_fuzz
            # ideally using another pattern which will iterate over the
            # different generators
            value_db <- sxpdb::open_db(DB_DIR)
            generator <- create_existing_args_generator(
                functions_$pkg_name,
                functions_$fun_name,
                value_db,
                origins_db
            )
            runner <- runner_start()
            withr::defer(runner_stop(runner), envir = runner)
            runner_fun <- create_fuzz_runner(DB_DIR, runner)

            fuzz(
                functions_$pkg_name,
                functions_$fun_name,
                generator = generator,
                runner = runner_fun,
                quiet = FALSE
            )

        },
        pattern = map(functions_)
    ),
    tar_target(
        run_fuzz,
        {
            value_db <- sxpdb::open_db(DB_DIR)
            generator <- create_fd_args_generator(
                functions_$pkg_name,
                functions_$fun_name,
                value_db,
                origins_db,
                meta_db = NULL,
                budget = BUDGET
            )
            runner <- runner_start()
            withr::defer(runner_stop(runner), envir = runner)
            runner_fun <- create_fuzz_runner(DB_DIR, runner)

            fuzz(
                functions_$pkg_name,
                functions_$fun_name,
                generator = generator,
                runner = runner_fun,
                quiet = FALSE
            )
        },
        pattern = map(functions_),
        error = "continue"
    )
)
