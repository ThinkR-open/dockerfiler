
#' Generate base image name
#'
#' Creates the base image name from the provided distro name and the R version found in the `renv.lock` file.
#'
#' @keywords internal
#' @noRd
gen_base_image <- function(
  distro = NULL,
  r_version = "4.0",
  FROM = "rstudio/r-base"
) {

if (!is.null(distro)){
  warning("the `distro` parameter is not used anymore, only debian/ubuntu based images are supported")
}

    glue::glue("{FROM}:{r_version}")

}
