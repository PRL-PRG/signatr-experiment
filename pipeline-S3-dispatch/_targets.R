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


#plan(callr)
plan(multicore)

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
    S3_dispatch,
    {
      library(packages_to_run, character.only = TRUE)
      runr::metadata_functions(packages_to_run)
    }
  )
)