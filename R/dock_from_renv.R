
#' @importFrom memoise memoise
#' @noRd
pkg_sysreqs_mem <- memoise::memoise(
    pak::pkg_sysreqs
)


#' Create a Dockerfile from an `renv.lock` file
#'
#' @param lockfile Path to an `renv.lock` file to use as an input..
#' @param FROM Docker image to start FROM Default is FROM rocker/r-base
#' @param AS The AS of the Dockerfile. Default it `NULL`.
#' @param distro - deprecated - only debian/ubuntu based images are supported
#' @param sysreqs boolean. If `TRUE`, the Dockerfile will contain sysreq installation.
#' @param expand boolean. If `TRUE` each system requirement will have its own `RUN` line.
#' @param repos character. The URL(s) of the repositories to use for `options("repos")`.
#' @param extra_sysreqs character vector. Extra debian system requirements.
#'    Will be installed with apt-get install.
#' @param renv_version character. The renv version to use in the generated Dockerfile. By default, it is set to the version specified in the `renv.lock` file.
#'   If the `renv.lock` file does not specify a renv version,
#'   the version of renv bundled with dockerfiler,
#'   specifically `r dockerfiler::renv$initialize();toString(dockerfiler::renv$the$metadata$version)`, will be used.
#'   If you set it to `NULL`, the latest available version of renv will be used.
#' @param use_pak boolean. If `TRUE` use pak to deal with dependencies  during `renv::restore()`. FALSE by default
#' @param user Name of the user to specify in the Dockerfile with the USER instruction. Default is `NULL`, in which case the user from the FROM image is used.
#' @param dependencies What kinds of dependencies to install. Most commonly
#'   one of the following values:
#'   - `NA`: only required (hard) dependencies,
#'   - `TRUE`: required dependencies plus optional and development
#'     dependencies,
#'   - `FALSE`: do not install any dependencies. (You might end up with a
#'     non-working package, and/or the installation might fail.)
#' @param sysreqs_platform System requirements platform.`ubuntu` by default. If `NULL`, then the  current platform is used. Can be : "ubuntu-22.04" if needed to fit with the `FROM` Operating System. Only debian or ubuntu based images are supported
#' @param github_pat character. How to provide a GitHub PAT to
#'   `renv::restore()` for private dependency repositories. One of
#'   `"none"` (default; the generated Dockerfile does not reference
#'   any PAT), `"build_arg"` (emit `ARG GITHUB_PAT` + `ENV` propagation;
#'   pass with `--build-arg GITHUB_PAT=$GITHUB_PAT`; the PAT will be
#'   visible in the image metadata), or `"secret"` (BuildKit secret
#'   mount on the `renv::restore()` RUN; the PAT is never persisted in
#'   the image; requires BuildKit, so pass with
#'   `DOCKER_BUILDKIT=1 docker build --secret id=github_pat,env=GITHUB_PAT ...`).
#' @importFrom utils getFromNamespace
#' @return A R6 object of class `Dockerfile`.
#' @details
#'
#' System requirements for packages are provided
#' through RStudio Package Manager via the pak
#' package. The install commands provided from pak
#' are added as `RUN` directives within the `Dockerfile`.
#'
#' The R version is taken from the `renv.lock` file.
#' Packages are installed using `renv::restore()` which ensures
#' that the proper package version and source is used when installed.
#'
#' @importFrom attempt map_try_catch
#' @importFrom glue glue
#' @importFrom pak pkg_sysreqs
#' @importFrom purrr keep_at pluck

#' @export
#' @examples
#' \dontrun{
#' dock <- dock_from_renv("renv.lock", distro = "xenial")
#' dock$write("Dockerfile")
#' }
dock_from_renv <- function(
  lockfile = "renv.lock",
  distro = NULL,
  FROM = "rocker/r-base",
  AS = NULL,
  sysreqs = TRUE,
  repos = c(CRAN = "https://cran.rstudio.com/"),
  expand = FALSE,
  extra_sysreqs = NULL,
  use_pak = FALSE,
  user = NULL,
  dependencies = NA,
  sysreqs_platform = "ubuntu",
  renv_version,
  github_pat = c("none", "build_arg", "secret")
) {
  github_pat <- match.arg(github_pat)
  try(dockerfiler::renv$initialize(),silent=TRUE)
  lock <- dockerfiler::renv$lockfile_read(file = lockfile) # using vendored renv
  # https://rstudio.github.io/renv/reference/vendor.html?q=vendor#null

  # start the dockerfile
  R_major_minor <- lock$R$Version
  dock <- Dockerfile$new(
    FROM = gen_base_image(
      r_version = R_major_minor,
      FROM = FROM
    ),
    AS = AS
  )
  .github_pat_setup(dock, github_pat)
  if (!is.null(user)) {
    dock$USER(user)
  }
  # get renv version

  if (missing(renv_version)) {
    if (!is.null(lock$Packages$renv$Version)) {
      renv_version <- lock$Packages$renv$Version
    } else {
      renv_version <-  dockerfiler::renv$the$metadata$version
    }
  }

  message("renv version = ",
          ifelse(!is.null(renv_version),renv_version,"the must up to date in the repos")
          )


  distro_args <- list(sysreqs_platform = sysreqs_platform)

  install_cmd <- "apt-get install -y"
  update_cmd <-"apt-get update -y"
  clean_cmd <- "rm -rf /var/lib/apt/lists/*"

  pkgs <- names(lock$Packages)

  if (sysreqs) {

    # please wait during system requirement calculation
    cat_bullet(
      "Please wait while we compute system requirements...",
      bullet = "info",
      bullet_col = "green"
    )

    message(
      sprintf(
        "Fetching system dependencies for %s package(s) records.",
        length(pkgs)
      )
    )

    pkg_os <- lapply(
      pkgs,
      FUN = function(x) {
        c(
          list(pkg = x,
               dependencies = dependencies),
          distro_args
        )
      }
    )


    pkg_sysreqs <- unlist(attempt::map_try_catch(
      pkg_os,
      function(x) {
        keep_at(
          pluck(
            do.call(pkg_sysreqs_mem, x),
            "packages"
          ),
          "system_packages"
        )
      },
      .e = ~ character(0)
    ))





    pkg_installs <-
      lapply(
        X = unique(pkg_sysreqs),
        FUN = function(.x) {
          paste0(install_cmd, " ", .x)
        }
      )

    if (length(unlist(pkg_installs)) == 0) {
      cat_bullet(
        "No sysreqs required",
        bullet = "info",
        bullet_col = "green"
      )
    }

    cat_green_tick("Done") # TODO animated version ?
  } else {
    pkg_installs <- NULL
  }

  # extra_sysreqs




  if (length(extra_sysreqs) > 0) {
    extra <- paste(
      install_cmd,
      extra_sysreqs
    )
    pkg_installs <- unique(c(pkg_installs, extra))
  }





  # compact
  if (!expand) {
    # we compact sysreqs
    pkg_installs <- compact_sysreqs(
      pkg_installs,
      update_cmd = update_cmd,
      install_cmd = install_cmd,
      clean_cmd = clean_cmd
    )

  } else {
    dock$RUN(update_cmd)
  }

  do.call(dock$RUN, list(pkg_installs))

  if (expand) {
    dock$RUN(clean_cmd)
  }

  repos_as_character <- repos_as_character(repos)
  dock$RUN("mkdir -p /usr/local/lib/R/etc/ /usr/lib/R/etc/")

  dock$RUN(
    sprintf(
      "echo \"options(renv.config.pak.enabled = %s, repos = %s, download.file.method = 'libcurl', Ncpus = 4)\" | tee /usr/local/lib/R/etc/Rprofile.site | tee /usr/lib/R/etc/Rprofile.site",
      use_pak,
      repos_as_character
    )
  )
  .patch_rprofile_for_ppm(dock, repos)


  if (!is.null(renv_version)){
    dock$RUN("R -e 'install.packages(\"remotes\")'")
      install_renv_string <- paste0(
        "R -e 'remotes::install_version(\"renv\", version = \"",
        renv_version,
        "\")'"
      )
      dock$RUN(install_renv_string)

  } else {
    # renv_version = NULL: use the latest renv from the configured repos.
    # `remotes` is only needed for the install_version() path above.
    dock$RUN("R -e 'install.packages(\"renv\")'")
  }

  dock$COPY(basename(lockfile), "renv.lock")
  dock$RUN(
    paste0(
      "--mount=type=cache,id=renv-cache,target=/root/.cache/R/renv ",
      .github_pat_run_prefix(github_pat),
      "R -e 'renv::restore()'"
    )
  )
  .github_pat_announce(github_pat)
  dock
}


#' Patch the Rprofile.site line so PPM serves Linux binaries.
#'
#' Modifications applied conditionally to the `RUN ... tee Rprofile.site`
#' line previously written by `dock_from_renv()`:
#'  1. CRAN URL rewritten to the `__linux__/$VERSION_CODENAME/` PPM variant
#'     (codename resolved from /etc/os-release at image build time). Skipped
#'     if the user already pinned a codename or a snapshot date.
#'  2. `HTTPUserAgent` added in the strict format required by PPM
#'     (`R (<version> <platform> <arch> <os>)`). Without it, PPM falls back
#'     to source even with a `__linux__/` URL.
#'  3. `renv.config.repos.override` set to the same PPM URL, so that
#'     `renv::restore()` uses PPM instead of the repo URL recorded in the
#'     lockfile (renv prefers lockfile repos by default; without this
#'     override, fixes 1 and 2 are bypassed during `restore()`).
#'  4. The `RUN` is prefixed with `. /etc/os-release && ` when (and only
#'     when) `$VERSION_CODENAME` ends up in the line.
#'
#' Only fires when `repos` is a single-entry vector named `CRAN` whose URL
#' is on PPM. Multi-entry vectors and other shapes are intentionally left
#' untouched -- rebuilding a multi-key `repos = c(...)` block robustly is
#' out of scope.
#' @noRd
.patch_rprofile_for_ppm <- function(dock, repos) {
  ppm_pattern <- "^https?://packagemanager\\.(posit|rstudio)\\.(co|com)/"
  if (length(repos) != 1L || !identical(names(repos), "CRAN")) {
    return(invisible(NULL))
  }
  user_url <- repos[["CRAN"]]
  if (!grepl(ppm_pattern, user_url)) {
    return(invisible(NULL))
  }

  rps_idx <- grep("tee /usr/local/lib/R/etc/Rprofile\\.site", dock$Dockerfile)
  if (length(rps_idx) != 1L) return(invisible(NULL))

  patched <- dock$Dockerfile[rps_idx]

  # Strip a single trailing slash so `cran/latest/` matches `cran/latest`.
  user_url_norm <- sub("/$", "", user_url)
  # Preserve the user's scheme + host (so a `packagemanager.rstudio.com`
  # URL or an internal mirror is not silently rewritten to posit.co).
  user_host_prefix <- sub("/cran(/.*)?$", "", user_url_norm)

  # Only rewrite when the URL is the bare `cran` or `cran/latest` form.
  # Anything else (already-pinned codename, snapshot date, custom path)
  # is left alone so we never silently clobber the user's intent.
  url_suffix <- sub("^.*/cran/?", "", user_url_norm)
  rewrite_url <- url_suffix == "" || url_suffix == "latest"
  if (rewrite_url) {
    rewritten_url <- sprintf(
      "%s/cran/__linux__/$VERSION_CODENAME/latest",
      user_host_prefix
    )
    patched <- sub(
      "repos = c\\(CRAN = '[^']*'\\)",
      sprintf("repos = c(CRAN = '%s')", rewritten_url),
      patched
    )
    override_url <- rewritten_url
  } else {
    override_url <- user_url
  }

  # Force renv::restore() to use the configured PPM URL instead of the repos
  # recorded in the lockfile (cf. ?renv::config -- option declared as
  # "primarily useful for deployment / continuous integration"). Without
  # this, the URL rewrite above is bypassed during restore().
  if (!grepl("renv\\.config\\.repos\\.override", patched)) {
    repos_override <- sprintf(
      ", renv.config.repos.override = c(CRAN = '%s')",
      override_url
    )
    patched <- sub(
      "(renv\\.config\\.pak\\.enabled = (TRUE|FALSE))",
      paste0("\\1", repos_override),
      patched
    )
  }

  # The quadruple backslashes produce a literal `\$` in the Dockerfile RUN,
  # so the shell does not expand $platform / $arch / $os and R sees them as
  # R.Version()$platform when sourcing Rprofile.site.
  user_agent <- paste0(
    ", HTTPUserAgent = sprintf('R (%s %s %s %s)',",
    " getRversion(),",
    " R.Version()\\\\$platform, R.Version()\\\\$arch, R.Version()\\\\$os)"
  )
  if (!grepl("HTTPUserAgent", patched)) {
    patched <- sub(
      "(, Ncpus = [0-9]+)\\)",
      paste0("\\1", user_agent, ")"),
      patched
    )
  }

  # Only prefix `. /etc/os-release && ` when the line actually references
  # $VERSION_CODENAME -- otherwise the prefix is dead weight.
  if (grepl("\\$VERSION_CODENAME", patched) &&
      !grepl("/etc/os-release", patched)) {
    patched <- sub("^RUN ", "RUN . /etc/os-release && ", patched)
  }

  dock$Dockerfile[rps_idx] <- patched
  invisible(NULL)
}

