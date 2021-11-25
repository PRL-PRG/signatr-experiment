library(targets)
library(tarchetypes)
library(future)
library(future.callr)
source("R/functions.R")
options(tidyverse.quiet = TRUE)
options(future.wait.timeout = 60 * 60) # do not allow more than 1h for each task

lib_path = normalizePath("library-local", mustWork = TRUE)
output_path = "data"
extracted_output = file.path(output_path, "extracted-code")
sxpdb_output = file.path(output_path, "sxpdb")
r_envir = c(callr::rcmd_safe_env(),
           "R_KEEP_PKG_SOURCE"=1,
           "R_ENABLE_JIT"=0,
           "R_COMPILE_PKGS"=0,
           "R_DISABLE_BYTECODE"=1)

plan(callr)

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

tar_option_set(
  packages = c("readr", "covr", "magrittr", "dplyr", "stringr"),
  #imports = c("sxpdb", "argtracer"),
  #error = "continue" # always continue by default
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
    deployment = "main"
  ),

  tar_target(
    extracted_files,
    extract_code_from_package(packages_to_run, lib_path, extracted_output),
    #deployment = "main",
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
    #format = "file", # what if it takes ages to hash all the databases?
    # then we can just return the paths but ask targets not to look at the files themselves and assume everything is fine
    # or use a time cue instead of using a hash one?
    pattern = map(individual_files)
  ),

  # tar_target(
  #   run_results,
  #   run_file(individual_files, lib_path),
  #   pattern = map(individual_files)
  # ),

  tar_target(
    run_results2,
    run_file2(individual_files, lib_path, r_home = "R-4.0.2"),
    pattern = map(individual_files)
  ),

  tar_target(
    merged_db,
    merge_db(traced_results, sxpdb_output),
    format = "file"
  )
)
