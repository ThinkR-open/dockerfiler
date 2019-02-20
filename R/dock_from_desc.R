#' Docker file from DESCRIPTION
#'
#' This function will parse a DESCRIPTION file and
#' create a Dockerfile that remotes::install_cran
#' all the functions from the Imports section.
#'
#' @param path Path to DESCRIPTION
#' @param FROM FROM of the Dockerfile
#' @param AS AS of the Dockerfile
#'
#' @return
#' @export
#'
#' @examples
dock_from_desc <- function(path = "DESCRIPTION", FROM = "rocker/r-base", AS = NULL){

  x <- Dockerfile$new(FROM, AS)
  x$RUN(r(install.packages('remotes')))

  desc <- read.dcf(path)
  desc <- desc[, "Imports"]
  desc <- gsub(",", "", desc)
  desc <- strsplit(desc, "\n")[[1]]
  for (i in seq_along(desc)){
    x$RUN(paste0("R -e 'remotes::install_cran(\"", desc[i], "\")'"))
  }

  x
}
