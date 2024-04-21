#' Get system requirements
#'
#' This function retrieves information about the
#' system requirements using the `pak::pkg_sysreqs()`.
#'
#' @param packages character vector. Packages names.
#' @param batch_n numeric. Number of simultaneous packages to ask.
#' @param quiet Boolean. If `TRUE` the function is quiet.
#'
#' @importFrom utils download.file
#' @importFrom jsonlite fromJSON
#' @importFrom remotes package_deps
#'
#' @export
#'
#' @return A vector of system requirements.
get_sysreqs <- function(
  packages,
  quiet = TRUE,
  batch_n = 30
) {
  all_deps <- sort(
    unique(
      c(
        packages,
        unlist(
          remotes::package_deps(packages)$package
        )
      )
    )
  )
  raw_output <- pak::pkg_sysreqs(pkg = all_deps,sysreqs_platform = "debian")
  unlist(raw_output$packages$system_packages)
  out <- unlist(raw_output$packages$system_packages)
  sort(unique(out[!is.na(out)]))
}

