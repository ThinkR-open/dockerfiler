# ignoring opensuse for the time being
available_distros <- c("xenial" , "bionic" , "focal" , "centos7" , "centos8")


#' Create a Dockerfile from an `renv.lock` file
#'
#' @param lockfile Path to an `renv.lock` file.
#' @param distro One of "focal", "bionic", "xenial", "centos7", or "centos8". See available distributions at https://hub.docker.com/r/rstudio/r-base/.
#' @param out_dir The directory where to write the `Dockerfile`. When `NULL` no file is written. `NULL` by default.
#' @param FROM Docker image to start FROM
#' @param repos CRAN repository to use inside the Dockerfile
#'
#' @importFrom utils getFromNamespace
#' @importFrom purrr possibly
#' @importFrom pak pkg_system_requirements
#' @return A R6 object of class `Dockerfile`.
#' @details
#'
#' System requirements for packages are provided through RStudio Package Manager via the {pak} package. The install commands provided from pak are added as `RUN` directives within the `Dockerfile`.
#'
#' The R version is taken from the `renv.lock` file. Packages are installed using `renv::restore()` which ensures that the proper package version and source is used when installed.
#'
#' By default, `dock_from_renv()` will utilize the [public RStudio Package Manager](https://packagemanager.rstudio.com/) (PPM) to provide linux binaries. This dramatically improves install time. This is done when `use_rspm = TRUE`.  To do so, a new file `renv.lock.dock` will be created so as to not overwrite your existing `renv.lock` file. This new `renv.lock.dock` file is used to build the Docker image with PPM binaries.
#'
#' @examples
#' \dontrun{
#' dock <- dock_from_renv("renv.lock", distro = "xenial", out_dir = getwd())
#' dock
#' }
#' @export
dock_from_renv <- function(lockfile = "renv.lock",
                           distro = "focal",
                           out_dir = NULL,
                           FROM = "rocker/r-base",
                           repos = c(
                             RSPM = paste0("https://packagemanager.rstudio.com/all/__linux__/", distro, "}/latest"),
                             CRAN = "https://cran.rstudio.com/")
                           ) {

  distro <- match.arg(distro, available_distros)

  lock <- getFromNamespace("lockfile", "renv")(lockfile)

  # change to public package manager by default, if false use default repo
  # if (use_rspm) {
    lock$repos(CRAN = repos)
    # write to tempfile
    lockfile <- paste0(lockfile, ".dock")
    lock$write(lockfile)
  # }

  # start the dockerfile
  R_major_minor <- paste(strsplit(lock$data()$R$Version, "[.]")[[1]][1:2], collapse = ".")
  dock <- Dockerfile$new(
    gen_base_image(
      distro = distro,
      r_version = R_major_minor,
      FROM = FROM
    ))

  distro_args <- switch(
    distro,
    centos7 = list(os = "centos", os_release = "7"),
    centos8 = list(os = "centos", os_release = "8"),
    xenial = list(os = "ubuntu", os_release = "16.04"),
    bionic = list(os = "ubuntu", os_release = "18.04"),
    focal = list(os = "ubuntu", os_release = "20.04")
  )

  pkgs <- names(lock$data()$Packages)

  pkg_os <- lapply(pkgs, FUN = function(x) c(list(package = x), distro_args))

  message(sprintf("Fetching system dependencies for %s package records.", length(pkgs)))


  psr <- purrr::possibly(pak::pkg_system_requirements,otherwise = character(0))
  pkg_sysreqs <- lapply(pkg_os, function(x) do.call(psr, x))


  pkg_installs <- unique(unlist(pkg_sysreqs))

  if (distro_args$os %in% c("ubuntu")) {
    dock$RUN("apt-get update -y")
  }

  do.call(dock$RUN, list(pkg_installs))

  repos_as_character <- repos_as_character(repos)
  dock$RUN(
    sprintf(
      "echo \"options(renv.config.pak.enabled = TRUE, repos = %s, download.file.method = 'libcurl', Ncpus = 4)\" >> /usr/local/lib/R/etc/Rprofile.site",
      repos_as_character
    )
  )

  renv_install <- glue::glue("install.packages('renv')")

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
gen_base_image <- function(distro = "bionic",
                           r_version = "4.0",
                           FROM = "rstudio/r-base") {

  distro <- match.arg(distro, available_distros)

  if (FROM == "rstudio/r-base") {
    glue::glue("{FROM}:{r_version}-{distro}")
  } else {
    glue::glue("{FROM}:{r_version}")
  }
}
