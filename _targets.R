library(targets)
library(tarchetypes)
library(future)
library(future.callr)
source("R/functions.R")
options(tidyverse.quiet = TRUE)
options(genthat.source_paths = source_path)
options(future.wait.timeout = 60 * 60) # do not allow more than 1h for each task


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
  packages = c("sxpdb", "argtracer", "readr", "covr", "magrittr", "dplyr"),
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
    install_cran_packages(packages_to_install, lib_path, source_path),
    deployment = "main"
  ),

  tar_target(
    extracted_files,
    extract_code_from_package(packages_to_run),
    #deployment = "main",
    format = "file"
  ),

  tar_target(
    traced_results,
    trace_file(traced_results),
    format = "file" # what if it takes ages to hash all the databases?
    # then we can just return the paths but ask targets not to look at the files themselves and assume everything is fine
    # or use a time cue instead of using a hash one?
  ),

  tar_target(
    traced_packages,
    # Slice to only keep the ones from a package
    merge_package_files(packages_to_run, traced_results),
    format = "file"
  ),

  tar_target(
    merged_trace,
    merge_packages(traced_packages),
    format = "file"
  )

)
