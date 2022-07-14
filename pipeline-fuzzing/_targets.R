library(dplyr)
library(future)
library(future.callr)
library(generatr)
library(sxpdb)
library(tarchetypes)
library(targets)
library(tibble)
library(withr)

source("R/fuzz.R")

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
DB_DIR <- Sys.getenv("DB_DIR", "/mnt/ocfs_vol_00/cran_db-6/")
BUDGET <- 5000
# maximum time allowed for a function call
TIMEOUT_MS <- 60 * 1000

# packages to test
# CORPUS <- c("stringr", "dplyr")
CORPUS <-
    readLines("../pipeline-dbgen/data/packages-typer-400.txt") %>%
    trimws(which = "both") %>%
    unique()

tar_option_set(
    # we want to keep this as small as possible to cut the workers startup time
    packages = c("magrittr", "targets"),
    format = "qs",
    workspace_on_error = TRUE
)

plan(multicore)

print(OUT_DIR)
print(LIB_DIR)
print(DB_DIR)

lib_dir <- create_dir(LIB_DIR)
full_lib_dir <- c(LIB_DIR, .libPaths())
run_fuzz_base_rdb_path <- next_file(file.path(OUT_DIR, "fuzz-base-rdb-"))

list(
    tar_target(
        packages_bin,
        {
            runr::install_cran_packages(
                CORPUS,
                lib_dir,
                dependencies = TRUE,
                check = FALSE
            ) %>% dplyr::pull(dir)
        },
        format = "file",
        deployment = "main"
    ),
    tar_target(
        packages,
        {
            package <- basename(packages_bin)
            version <- sapply(package, function(x) as.character(packageVersion(x, lib.loc = lib_dir)))
            tibble::tibble(package, version)
        }
    ),
    tar_target(
        functions,
        {
            runr::metadata_functions(packages$package, lib_loc = lib_dir) %>%
                dplyr::filter(exported, !is_s3_method) %>%
                # dplyr::filter(!grepl("...", params, fixed = TRUE)) %>%
                dplyr::filter(nchar(params) > 0)
        },
        pattern = map(packages)
    ),
    # tar_group_by(
    #     functions_,
    #     dplyr::bind_rows(functions),
    #     pkg_name, fun_name
    # ),
    tar_target(
        origins_db,
        {
            value_db <- sxpdb::open_db(DB_DIR)
            sxpdb::view_origins_db(value_db) %>%
                tibble::as_tibble() %>%
                dplyr::semi_join(functions, by = c("pkg" = "pkg_name", "fun" = "fun_name"))
        }
    ),
    tar_group_by(
        origins_db_pkg,
        origins_db,
        pkg
    ),
    tar_group_by(
        origins_db_pkg_fun,
        origins_db,
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
    #         str(origins_db_pkg_fun)
    #         list(o=origins_db_pkg_fun$pkg, f=origins_db_pkg_fun$fun, s=nrow(origins_db_pkg_fun))
    #     },
    #     pattern = map(origins_db_pkg_fun)
    # ),
    tar_target(
        run_existing,
        {
            # TODO: can the code be somehow shared between
            # run_existing / run_fuzz
            # ideally using another pattern which will iterate over the
            # different generators
            # TODO: what if origins_db is empty?
            pkg_name <- origins_db_pkg$pkg[1]
            value_db <- sxpdb::open_db(DB_DIR)
            runner <- generatr::runner_start(lib_loc = full_lib_dir)
            runner_fun <- generatr::create_fuzz_runner(DB_DIR, runner, timeout_ms = TIMEOUT_MS)
            withr::defer(generatr::runner_stop(runner), envir = runner)

            dfs <- lapply(
                unique(origins_db_pkg$fun),
                function(fun_name) {
                    generator <- generatr::create_existing_args_generator(
                        pkg_name,
                        fun_name,
                        value_db,
                        dplyr::filter(origins_db_pkg, fun == fun_name),
                        lib_loc = full_lib_dir
                    )

                    generatr::fuzz(
                        pkg_name,
                        fun_name,
                        generator = generator,
                        runner = runner_fun,
                        quiet = FALSE
                    ) %>%
                        dplyr::mutate(pkg_name = pkg_name, fun_name = fun_name)
                }
            )

            dplyr::bind_rows(dfs)
        },
        pattern = map(origins_db_pkg),
        error = "continue"
    ),
    tar_target(
        run_fuzz,
        {
            pkg_name <- origins_db_pkg_fun$pkg[1]
            fun_name <- origins_db_pkg_fun$fun[1]
            do_fuzz(
                pkg_name = pkg_name,
                fun_name = fun_name,
                db_path = DB_DIR,
                origins_db = origins_db_pkg_fun,
                lib_loc = full_lib_dir,
                budget_runs = BUDGET,
                budget_time_s = 60 * 60,
                timeout_one_call_ms = 60 * 1000,
                quiet = FALSE
            )
        },
        pattern = map(origins_db_pkg_fun),
        error = "continue"
    ),
    tar_target(
        base_functions,
        tribble(
            ~pkg_name, ~fun_name,
            "base", "grep",
            "basewrap", "wrap_length",
            "basewrap", "wrap_sin",
            "basewrap", "wrap_+",
            "basewrap", "wrap_-",
            "basewrap", "wrap_*",
            "basewrap", "wrap_div",
            "basewrap", "wrap_^",
            "basewrap", "wrap_unary_+",
            "basewrap", "wrap_unary_-",
            "basewrap", "wrap_%div%",
            "basewrap", "wrap_%%"
        )
    ),
    tar_target(
        run_fuzz_base,
        {
            rdb_path <- file.path(
                run_fuzz_base_rdb_path,
                paste0(base_functions$pkg_name, "::", base_functions$fun_name)
            )

            do_fuzz(
                pkg_name = base_functions$pkg_name,
                fun_name = base_functions$fun_name,
                db_path = DB_DIR,
                origins_db = tibble(id=integer(0), pkg=character(0), fun=character(0), param=character(0)),
                lib_loc = full_lib_dir,
                rdb_path = rdb_path,
                budget_runs = 10,
                budget_time_s = 60 * 60,
                timeout_one_call_ms = 60 * 1000,
                quiet = FALSE
            )
        },
        pattern = map(base_functions),
        error = "continue"
    )
)
