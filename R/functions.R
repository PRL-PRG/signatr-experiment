install_cran_packages <- function(packages_to_install,
                                  lib=NULL,
                                  destdir=NULL,
                                  mirror = "https://cloud.r-project.org/") {
  options(repos=mirror)

  requested <- packages_to_install

  installed <- installed.packages(lib.loc=lib)[,1]
  missing <- setdiff(requested, installed)

  message("Installing ", length(missing), " packages from ", mirror, " into ", lib)

  if (length(missing) > 0) {
    if (!is.null(destdir) && !dir.exists(destdir)) dir.create(destdir, recursive=TRUE)
    if (!is.null(lib) && !dir.exists(lib)) dir.create(lib, recursive=TRUE)
  }

  # set package installation timeout
  Sys.setenv(
    `_R_INSTALL_PACKAGES_ELAPSED_TIMEOUT_`=Sys.getenv("_R_INSTALL_PACKAGES_ELAPSED_TIMEOUT_", "5000")
  )

  install.packages(
    missing,
    lib=lib,
    destdir=destdir,
    dependencies=TRUE,
    INSTALL_opts=c("--example", "--install-tests", "--with-keep.source", "--no-multiarch"),
    Ncpus=floor(.9*parallel::detectCores())
  )

  installed <- installed.packages(lib.loc=lib)[,1]
  successful_installed <- intersect(installed, requested)

  # Extract the sources from the missing ones that successfully installed
  installed_missing <- intersect(successful_installed, missing)


  archives <- list.files(destdir, pattern = "\\.tar\\.gz$", full.names = TRUE)
  for(package in installed_missing) {
    destfiles <- grep(package, archives, value = TRUE, fixed = TRUE)
    if(length(destfiles) == 0) {
      next;
    }
    destfile <- destfiles[[1]] # there should be only one anyway
    pkgdir <- file.path(destdir, package)
    if(dir.exists(pkgdir)) {
      warning("Destination directory for extracting exists ", pkgdir, "\n")
    }
    message("Extracting", destfile ," to ", pkgdir, "\n")
    utils::untar(destfile, exdir=destdir)
    file.remove(destfile) # remove the archive so that it does not interfere with newer versions
    # It does not remove the tar of the dependencies though...
  }

  successful_installed
}

extract_code_from_package <- function(package) {
  # extract codes, should return the path of all extracted files...
  # so maybe do it with 2 functions, one for the examples, and one for the rest
  # to be able to feed the concatenation for the examples
}


concatenate_examples <- function(package, examples) {
  # This takes all the extracted examples of the package and generates one example file
  # This is in order to speed up the tracing
}

trace_file <- function(file) {
  # Put the right arch, the right libPaths and so on
  callr::r(function() trace_file(file), arch="")
}
