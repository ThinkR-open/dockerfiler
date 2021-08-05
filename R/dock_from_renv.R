#' Create a Dockerfile from an `renv.lock` file
#'
#' @param lockfile Path to an `renv.lock` file.
#' @param distro One of "focal", "bionic", "xenial", "centos7", or "centos8". See available distributions at https://hub.docker.com/r/rstudio/r-base/.
#' @param primary_repo Default "CRAN". Indicates which repository in the `renv.lock` file to install the renv package from.
#' @param out_dir The directory where to write the `Dockerfile`. When `NULL` no file is written. `NULL` by default.
#' @param use_rspm Utilize the Public RStudio Package Manager for Linux binaries. Default `TRUE`.
#'
#' @return A R6 object of class `Dockerfile`.
#' @details
#'
#' System requirements for packages are provided through RStudio Package Manager via the {pak} package. The install commands provided from pak are added as `RUN` directives within the `Dockerfile`.
#'
#' The R version is taken from the `renv.lock` file. Packages are installed using `renv::restore()` which ensures that the proper package version and source is used when installed.
#'
#' By default, `dock_from_renv()` will utilize the [public RStudio Package Manager](https://packagemanager.rstudio.com/) (PPM) to provide linux binaries. This dramatically improves install time. This is done when `use_rspm = TRUE`.  To do so, a new file `renv.lock.dock` will be created so as to not overwrite your existing `renv.lock` file. This new `renv.lock.dock` file is used to build the Docker image with PPM binaries.
#'
#' \donttest{
#' dock <- dock_from_renv("renv.lock", distro = "xenial", out_dir = getwd())
#' dock
#' }
#' @export
dock_from_renv <- function(lockfile = "renv.lock", distro = "xenial", primary_repo = "CRAN",
                           out_dir = NULL,
                           use_rspm = TRUE) {

  lock <- renv:::lockfile(lockfile)

  # change to public package manager by default, if false use default repo
  if (use_rspm) {
    lock$repos(CRAN = glue::glue("https://packagemanager.rstudio.com/all/__linux__/{distro}/latest"))
    # write to tempfile
    lockfile <- paste0(lockfile, ".dock")
    lock$write(lockfile)
  }

  # start the dockerfile
  dock <- Dockerfile$new(gen_base_image(distro = distro, r_version = lock$version()))

  distro_args <- switch(distro,
                        centos7 = list(os = "centos", os_release = "7"),
                        centos8 = list(os = "centos", os_release = "8"),
                        xenial = list(os = "ubuntu", os_release = "16.04"),
                        bionic = list(os = "ubuntu", os_release = "18.04"),
                        focal = list(os = "ubuntu", os_release = "20.04")
  )


  pkgs <- names(lock$data()$Packages)

  pkg_os <- lapply(pkgs, FUN = function(x) c(list(package = x), distro_args))

  message(sprintf("Fetching system dependencies for %s package records.", length(pkgs)))

  pkg_sysreqs <- lapply(pkg_os, function(x) do.call(pak::pkg_system_requirements, x))

  pkg_installs <- unique(unlist(pkg_sysreqs))

  if (distro %in% c("xenial" , "bionic" , "focal")) {
    dock$RUN("apt-get update -y")
  }

  do.call(dock$RUN, list(pkg_installs))

  renv_install <- glue::glue("install.packages('renv', repo = '{lock$repos()[{primary_repo}]}')")

  dock$COPY(lockfile, "renv.lock")
  dock$RUN(glue::glue('R -e "{renv_install}"'))
  dock$RUN(r(renv::restore()))

  if (!is.null(out_dir)) dock$write(file.path(out_dir, "Dockerfile"))

  dock
}


#' Generate base image name
#'
#' Creates the base image name from the provided distro name and the R version found in the `renv.lock` file.
#'
#' @keywords internal
gen_base_image <- function(distro = "bionic", r_version = lock$version()) {

    # ignoring opensuse for the time being
  available_distros <- c("xenial" , "bionic" , "focal" , "centos7" , "centos8")

  match.arg(distro, available_distros)

  glue::glue("rstudio/r-base:{r_version}-{distro}")
}
