#' @export
`wrap_unary_+` <- function(x) +x

#' @export
`wrap_unary_-` <- function(x) -x

#' @export
`wrap_+` <- function(x, y) x + y

#' @export
`wrap_-` <- function(x, y) x - y

#' @export
`wrap_*` <- function(x, y) x * y

#' @export
`wrap_/` <- function(x, y) x / y

#' @export
`wrap_^` <- function(x, y) x ^ y

#' @export
`wrap_%%` <- function(x, y) x %% y

#' @export
`wrap_%/%` <- function(x, y) x %/% y

#' @export
wrap_length <- function(x) length(x)

#' @export
wrap_sin <- function(x) sin(x)
