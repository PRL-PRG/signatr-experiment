library(targets)
library(tarchetypes)
library(future)
library(future.callr)
library(progressr)
source("R/functions.R")
options(tidyverse.quiet = TRUE)
options(future.wait.timeout = 15 * 60) # do not allow more than 15min for each task

lib_path = normalizePath("../library", mustWork = TRUE)
output_path = "data"
extracted_output = file.path(output_path, "extracted-code")
sxpdb_output = file.path(output_path, "sxpdb")
r_envir = c(callr::rcmd_safe_env(),
            "R_KEEP_PKG_SOURCE"=1,
            "R_ENABLE_JIT"=0,
            "R_COMPILE_PKGS"=0,
            "R_DISABLE_BYTECODE"=1) # that one is a 10x performance hit!

#plan(callr)
plan(multicore) # seems to be much better than callr

# If you want to see the error messages, you can easily do it
# by looking at the result of target"_err"
tar_target_resilient <- function(name, command, pattern, ...) {
  tname <- deparse(substitute(name))
  tname_err <- paste0(tname, "_err")
  sym_err <- parse(text = tname_err)[[1]]
  wrapped_command <- substitute(tryCatch(COMMAND, error = function(e) e), list(COMMAND = substitute(command)))
  # Or Filter if we do not want to use purrr
  compact_command <- substitute(purrr::discard(TNAME_ERR, function(v) inherits(v, "error")), list(TNAME_ERR = sym_err))
  tpattern <- substitute(map(TNAME_ERR), list(TNAME_ERR = sym_err))
  list(
    tar_target_raw(tname_err, wrapped_command, pattern = substitute(pattern), iteration = "list", ...),
    tar_target_raw(tname, command = compact_command, pattern = tpattern)
  )
}

tar_target_resilient_file <- function(name, command, pattern, ...) {
  tname <- deparse(substitute(name))
  tname_err <- paste0(tname, "_err")
  sym_err <- parse(text = tname_err)[[1]]
  wrapped_command <- substitute(tryCatch(COMMAND, error = function(e) e), list(COMMAND = substitute(command)))
  # Or Filter if we do not want to use purrr
  compact_command <- substitute(purrr::discard(TNAME_ERR, function(v) inherits(v, "error") | !is.character(v) | length(v) != 1), list(TNAME_ERR = sym_err))
  list(
    tar_target_raw(tname_err, wrapped_command, pattern = substitute(pattern), iteration = "list", ...),
    tar_target_raw(tname, command = compact_command)
  )
}

tar_option_set(
  packages = c("readr", "covr", "magrittr", "dplyr", "stringr"),
  #imports = c("sxpdb", "argtracer"),
  #error = "continue" # always continue by default
  format = "qs"
)

list(
  tar_target(
    packages_file,
    "data/packages.txt",
    format = "file"
  ),
  tar_target(
    packages_to_install,
    unique(trimws(read_lines(packages_file)))
  ),
  tar_target(
    packages_to_run,
    install_cran_packages(packages_to_install, lib_path, NULL),
    deployment = "main",
    cue = tar_cue(mode = "always")
  ),

  tar_target(
    extracted_files,
    extract_code_from_package(packages_to_run, lib_path, extracted_output),
    format = "file",
    pattern = map(packages_to_run)
  ),

  tar_target(
    blacklist_file,
    "data/blacklist.txt",
    format = "file"
  ),
  tar_target(
    blacklist,
    unique(trimws(read_lines(blacklist_file)))
  ),

  tar_target(
    individual_files,
    remove_blacklisted(extracted_files, blacklist),
  ),

  tar_target(
    traced_results,
    trace_file(individual_files, lib_path, sxpdb_output),
    #format = "file",
    pattern = map(individual_files),
    #error = "abridge",
    error = "continue",
    priority = 1
  ),

  tar_target(
    db_blacklist_file,
    "data/db-blacklist.txt",
    format = "file"
  ),
  tar_target(
    db_blacklist,
    unique(trimws(read_lines(db_blacklist_file)))
  ),

  tar_target(
    traced_res,
    fix_traced_res(traced_results),
    map(traced_results),
    error = "continue"
  ),

  tar_target(
    db_paths,
    remove_blacklisted(traced_res$db_path, db_blacklist, only_real_paths=TRUE),
    format = "file"
  ),


  #tar_target(
  #  run_results2,
  #  run_file2(individual_files, lib_path, r_home = "R-4.0.2"),
  #  pattern = map(individual_files),
  #  cue = tar_cue(mode = "never")
  #),

  tar_target(
    merged_db,
    with_progress(
      merge_db(db_paths, sxpdb_output),
      enable = TRUE), # handlers =  handler_debug,
    #handler_progress(format   = ":spin :current/:total (:message) [:bar] :percent in :elapsed ETA: :eta")
    #handler_pbmcapply
    deployment = "main"
  )
)
