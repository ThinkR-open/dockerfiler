#' Turn an R call into an Unix call
#'
#' @param code the function to call
#'
#' @return an unix R call
#' @export
#'
#' @examples
#' r_this(print("yeay"))

r_this <- function(code){
  code <- substitute(code)
  glue("R -e '{code}'")
}
