install_cran_packages <- function(packages_to_install,
                                  lib = NULL,
                                  destdir = NULL,
                                  mirror = "https://cloud.r-project.org/") {
  options(repos = mirror)

  requested <- packages_to_install

  installed <- installed.packages(lib.loc = lib)[, 1]
  missing <- setdiff(requested, installed)

  message("Installing ",
          length(missing),
          " packages from ",
          mirror,
          " into ",
          lib)

  if (length(missing) > 0) {
    if (!is.null(destdir) &&
        !dir.exists(destdir))
      dir.create(destdir, recursive = TRUE)
    if (!is.null(lib) &&
        !dir.exists(lib))
      dir.create(lib, recursive = TRUE)
  }

  # set package installation timeout
  Sys.setenv(
    `_R_INSTALL_PACKAGES_ELAPSED_TIMEOUT_` = Sys.getenv("_R_INSTALL_PACKAGES_ELAPSED_TIMEOUT_", "5000")
  )

  callr::r(
    function(x) {
      install.packages(
        x,
        dependencies = TRUE,
        INSTALL_opts = c(
          "--example",
          "--install-tests",
          "--with-keep.source",
          "--no-multiarch"
        ),
        Ncpus = floor(.9 * parallel::detectCores())
      )
    },
    list(missing),
    libpath = lib_path,
    arch = "R-dyntrace/bin/R",
    show = TRUE,
    env = r_envir
  )

  installed <- installed.packages(lib.loc = lib)[, 1]
  successful_installed <- intersect(installed, requested)

  # Extract the sources from the missing ones that successfully installed
  installed_missing <- intersect(successful_installed, missing)

  if (!is.null(destdir)) {
    archives <-
      list.files(destdir, pattern = "\\.tar\\.gz$", full.names = TRUE)
    for (package in installed_missing) {
      destfiles <- grep(package, archives, value = TRUE, fixed = TRUE)
      if (length(destfiles) == 0) {
        next

      }
      destfile <- destfiles[[1]] # there should be only one anyway
      pkgdir <- file.path(destdir, package)
      if (dir.exists(pkgdir)) {
        warning("Destination directory for extracting exists ",
                pkgdir,
                "\n")
      }
      message("Extracting", destfile , " to ", pkgdir, "\n")
      utils::untar(destfile, exdir = destdir)
      file.remove(destfile) # remove the archive so that it does not interfere with newer versions
      # It does not remove the tar of the dependencies though...
    }
  }


  successful_installed
}


extract_code_from_package <- function(package, lib_path, output_path) {
    # extract codes, should return the path of all extracted files...
    # so maybe do it with 2 functions, one for the examples, and one for the rest
    # to be able to feed the concatenation for the examples
    runr::extract_package_code(package,
                               pkg_dir = file.path(lib_path, package),
                               output_dir = file.path(output_path, package),
			       split_testthat=TRUE) %>%
      mutate(file = file.path(normalizePath(output_path, mustWork = TRUE), package, file)) %>%
      pull(file)
  }


concatenate_examples <- function(package, examples) {
  # This takes all the extracted examples of the package and generates one example file
  # This is in order to speed up the tracing
}

trace_file <- function(file_path, lib_path, output_path) {
  output_path <- normalizePath(output_path)
  dir.create(output_path) # make sure the output path exists
  db_name <- paste(basename(dirname(dirname(file_path))), basename(dirname(file_path)), basename(file_path), sep = "-")
  db_path <- file.path(output_path, db_name)
  callr::r(
    function(x, y) {
      tracingState(on = FALSE)
      argtracer::trace_file(x, y)
    },
    list(file_path, db_path),
    libpath = lib_path,
    arch = normalizePath("R-dyntrace/bin/R", mustWork = TRUE),
    show = TRUE,
    env = r_envir,
    wd = dirname(file_path)
  )
}

run_file <- function(file_path, lib_path, r_home = "R-dyntrace") {
  # Put the right arch, the right libPaths and so on
  res <- callr::rcmd(
    "BATCH",
    c("--no-timing", basename(file_path)),
    libpath = lib_path,
    #arch = file.path(r_home, "bin", "R"),
    show = TRUE,
    wd = dirname(file_path),
    env = r_envir
  )
  tibble(
    file_path,
    status = res$status
  )
}

run_file2 <- function(file_path, lib_path,r_home = "R-dyntrace") {
  r_bin <- normalizePath(file.path(r_home, "bin", "R"), mustWork = TRUE)
  # Put the right arch, the right libPaths and so on
  status <- tryCatch({
    callr::r(
      function(x) {
        code <- parse(file = x)
        code <- as.call(c(`{`, code))
        eval(code)
      },
      list(file_path),
      libpath = lib_path,
      arch = r_bin,
      show = TRUE,
      #env = r_envir, #to uncomment if we want to cripple as much as R-dyntrace
      wd = dirname(file_path)
    )
    NA_character_},
    error = function(e) e$message)
  tibble(
    file_path,
    message = status,
    status = !is.na(status)
  )
}

merge_db <- function(db_paths, output_path) {
  db_path = file.path(normalizePath(output_path, mustWork = TRUE), "cran_db")
  p <- progressr::progressor(along=db_paths + 1)
  p(message = "Starting merging", amount = 0)
  db <- sxpdb::open_db(db_path)
  failed_dbs <- tibble(path = character(0), error = character(0), iteration = integer(0))
  i <- 1
  for(path in db_paths) {
    p(paste0("Merging ", path), amount = 0)
    tryCatch({
      small_db <- sxpdb::open_db(path)
      sxpdb::merge_db(db, small_db)
      p(message = paste0("Merged ", path, " ; DB size =", sxpdb::size_db(db)))
      sxpdb::close_db(small_db)
    },
    error = function(e) {
      failed_dbs <<- tibble::add_row(failed_dbs, path = path, error = as.character(e), iteration = i)
      p(message = paste0("Failure  ", path, "with error ", e), class = "sticky")
      }
    )
    i <- i + 1
  }
  sxpdb::close_db(db)
  p(message="Wrote metadata.")
  return(failed_dbs)
}

remove_blacklisted <- function(file_paths, blacklist, only_real_paths=FALSE) {
  filtered <- if(length(blacklist) != 0 ) {
    stringr::str_subset(file_paths, paste0(paste0(blacklist, collapse = "|"), "$"), negate = TRUE) 
  } else {
    file_paths
  }
  if(only_real_paths) {
    return(filtered[dir.exists(filtered)])
  }
  else {
    return(filtered)
  }
  
}
