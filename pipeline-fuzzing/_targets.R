library(dplyr)
library(future)
library(future.callr)
library(generatr)
library(tarchetypes)
library(targets)
library(tibble)
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

OUT_DIR <- Sys.getenv("OUT_DIR", "out")
LIB_DIR <- Sys.getenv("LIB_DIR", file.path(OUT_DIR, "library"))
DB_DIR <- Sys.getenv("DB_DIR", "/mnt/ocfs_vol_00/cran_db-5/")
BUDGET <- 3000
# maximum time allowed for a function call
TIMEOUT_MS <- 60 * 1000

# packages to test
# CORPUS <- c("stringr", "dplyr")
CORPUS <-
    readLines("/mnt/ocfs_vol_00/signatr/packages-94.txt") %>%
    trimws(which = "both") %>%
    unique()

tar_option_set(
    packages = c("dplyr", "generatr", "runr", "sxpdb", "withr"),
    format = "qs"
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
            runr::metadata_functions(packages$package, lib_loc = LIB_DIR) %>%
                dplyr::filter(exported, !is_s3_dispatch, !is_s3_method) %>%
                dplyr::filter(!grepl("...", params, fixed = TRUE))
        },
        pattern = map(packages)
    ),
    # tar_group_by(
    #     functions_,
    #     dplyr::bind_rows(functions),
    #     pkg_name, fun_name
    # ),
    tar_group_by(
        origins_db,
        {
            value_db <- sxpdb::open_db(DB_DIR)
            sxpdb::view_origins_db(value_db) %>%
                as_tibble %>%
                semi_join(functions, by = c("pkg" = "pkg_name", "fun" = "fun_name"))
        },
        pkg, fun
    ),
    tar_target(
        meta_db,
        {
            # value_db <- sxpdb::open_db(DB_DIR)
            # sxpdb::view_meta_db(value_db) %>%
            #     as_tibble
            NULL
        }
    ),
    # tar_target(
    #     t,
    #     {
    #         list(o=origins_db, f=functions_)
    #     },
    #     pattern = map(origins_db, functions_)
    # ),
    tar_target(
        run_existing,
        {
            # TODO: can the code be somehow shared between
            # run_existing / run_fuzz
            # ideally using another pattern which will iterate over the
            # different generators
            # TODO: what if origins_db is empty?
            pkg_name <- origins_db$pkg[1]
            fun_name <- origins_db$fun[1]
            value_db <- sxpdb::open_db(DB_DIR)
            generator <- create_existing_args_generator(
                pkg_name,
                fun_name,
                value_db,
                origins_db
            )
            runner <- runner_start()
            withr::defer(runner_stop(runner), envir = runner)
            runner_fun <- create_fuzz_runner(DB_DIR, runner, timeout_ms = TIMEOUT_MS)

            fuzz(
                pkg_name,
                fun_name,
                generator = generator,
                runner = runner_fun,
                quiet = FALSE
            ) %>%
                mutate(pkg_name = pkg_name, fun_name = fun_name)

        },
        pattern = map(origins_db),
        error = "continue"
    ),
    tar_target(
        run_fuzz,
        {
            pkg_name <- origins_db$pkg[1]
            fun_name <- origins_db$fun[1]
            value_db <- sxpdb::open_db(DB_DIR)
            generator <- create_fd_args_generator(
                pkg_name,
                fun_name,
                value_db,
                origins_db,
                meta_db = NULL,
                budget = BUDGET
            )
            runner <- runner_start()
            withr::defer(runner_stop(runner), envir = runner)
            runner_fun <- create_fuzz_runner(DB_DIR, runner, timeout_ms = TIMEOUT_MS)

            fuzz(
                pkg_name,
                fun_name,
                generator = generator,
                runner = runner_fun,
                quiet = TRUE
            ) %>%
                mutate(pkg_name = pkg_name, fun_name = fun_name)
        },
        pattern = map(origins_db),
        error = "continue"
    )
)
