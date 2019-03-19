#' Docker file from DESCRIPTION
#'
#' This function will parse a DESCRIPTION file and
#' create a Dockerfile that remotes::install_cran
#' all the functions from the Imports section, add
#' the COPY of the tar.gz of the package, and install
#' the package.
#'
#' @param path Path to DESCRIPTION
#' @param FROM FROM of the Dockerfile
#' @param AS AS of the Dockerfile
#'
#' @note After this Dockerfile is created, the package
#'     should be built and be put in the same directory
#'     as the dockerfile.
#'
#' @return A Dockerfile Object.
#' @export
#'
#' @importFrom utils installed.packages
#'
#' @examples
#' \dontrun{
#' my_dock <- dock_from_desc("DESCRIPTION")
#' my_dock
#' my_dock$CMD(r(library(dockerfiler)))
#' my_dock$add_after(
#' cmd = "RUN R -e 'remotes::install_cran(\"rlang\")'",
#' after = 3
#' )
#' }
dock_from_desc <- function(
  path = "DESCRIPTION",
  FROM = "rocker/r-base",
  AS = NULL
){

  x <- Dockerfile$new(FROM, AS)
  x$RUN("R -e 'install.packages(\"remotes\")'")

  # We need to be sure install_cran is there
  x$RUN("R -e 'remotes::install_github(\"r-lib/remotes\", ref = \"6c8fdaa\")'")

  desc <- read.dcf(path)

  # Handle cases where there is no deps
  imp <- attempt::attempt({
    desc[, "Imports"]
  }, silent = TRUE)

  if (class(imp)[1] != "try-error"){
    # Remove base packages which are not on CRAN
    # And shouldn't be installed
    reco <- rownames(installed.packages(priority="base"))

    if (length(imp) > 0) {

      imp <- gsub(",", "", imp)
      imp <- strsplit(imp, "\n")[[1]]
      for (i in seq_along(imp)){
        if (!(imp[i] %in% reco)){
          x$RUN(paste0("R -e 'remotes::install_cran(\"", imp[i], "\")'"))
        }
      }
    }
  }

  x$COPY(
    from = paste0(desc[1], "_*.tar.gz"),
    to = "/app.tar.gz"
  )
  x$RUN("R -e 'remotes::install_local(\"/app.tar.gz\")'")

  x
}
