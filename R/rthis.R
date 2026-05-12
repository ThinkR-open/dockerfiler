#' Turn an R expression into a shell `R -e '...'` call
#'
#' Captures an R expression unevaluated and renders it as a single
#' shell-quoted `R -e '...'` string, suitable for a [Dockerfile]
#' `$RUN()` directive.
#'
#' @param code an R expression (captured unevaluated) to wrap.
#'
#' @return a length-1 character string of the form `R -e '...'`,
#'   shell-quoted with [base::shQuote()].
#' @export
#'
#' @examples
#' r(print("yeay"))
#' r(install.packages("plumber", repos = "https://cloud.r-project.org"))
r <- function(code) {
  code <- paste(trimws(deparse(substitute(code))), collapse = " ")
  glue("R -e {shQuote(code, type = 'sh')}")
}
