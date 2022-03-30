do_fuzz <- function(pkg_name, fun_name,
                    db_path, origins_db, lib_loc,
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

    generatr::fuzz(
        pkg_name,
        fun_name,
        generator = generator,
        runner = runner_fun,
        quiet = quiet,
        timeout_s = budget_time_s
    ) %>%
        dplyr::mutate(pkg_name = pkg_name, fun_name = fun_name)
}
