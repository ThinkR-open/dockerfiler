#' Turn an R call into an Unix call
#'
#' @param code the function to call
#'
#' @return an unix R call
#' @export
#'
#' @examples
#' r(print("yeay"))
#' r(install.packages("plumber", repo = "http://cran.irsn.fr/"))
r <- function(code) {
  code <- paste(trimws(deparse(substitute(code))), collapse = " ")
  glue("R -e {shQuote(code, type = 'sh')}")
}
