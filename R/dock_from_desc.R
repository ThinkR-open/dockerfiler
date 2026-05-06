base_pkg_ <- c(
  "base",
  "boot",
  "class",
  "cluster",
  "codetools",
  "compiler",
  "datasets",
  "foreign",
  "graphics",
  "grDevices",
  "grid",
  "KernSmooth",
  "lattice",
  "MASS",
  "Matrix",
  "methods",
  "mgcv",
  "nlme",
  "nnet",
  "parallel",
  "rpart",
  "spatial",
  "splines",
  "stats",
  "stats4",
  "survival",
  "tcltk",
  "tools",
  "utils"
)

quote_not_na <- function(x){
  x[!is.na(x)] <- paste0('\"',x[!is.na(x)],'\"')
  x
}




#' Create a Dockerfile from a DESCRIPTION
#
#' @param path path to the DESCRIPTION file to use as an input.
#' @param FROM The FROM of the Dockerfile. Default is
#'   `paste0("rocker/r-ver:", R.Version()$major, ".", R.Version()$minor)`.
#'   Validated as a Docker image reference (alphanumerics, dot, slash,
#'   dash, underscore, optional `:tag` and / or `@sha256:<hex>`); other
#'   values raise an error to prevent shell-metacharacter injection
#'   into the generated FROM directive.
#' @param AS The AS of the Dockerfile. Default it NULL. When non-NULL,
#'   validated as a simple build-stage name (`^[a-zA-Z0-9][a-zA-Z0-9._-]*$`).
#' @param sysreqs boolean. If TRUE, the Dockerfile will contain sysreq installation.
#' @param repos character. The URL(s) of the repositories to use for
#'   `options("repos")`. Each value must look like an http(s) URL (no
#'   quotes, spaces or newlines); each name (when set) must be a simple
#'   identifier (`^[A-Za-z][A-Za-z0-9._-]*$`). Other values raise an
#'   error to prevent injection into the generated `echo "options(...)"`
#'   shell command.
#' @param expand boolean. If `TRUE` each system requirement will have its own `RUN` line.
#' @param build_from_source boolean. If `TRUE` no tar.gz is created and
#'     the Dockerfile directly mount the source folder.
#' @param update_tar_gz boolean. If `TRUE` and `build_from_source` is also `TRUE`,
#'     an updated tar.gz is created.
#' @param extra_sysreqs character vector. Extra debian system requirements.
#'   Will be installed with apt-get install. Each entry must be a Debian
#'   package name (`^[a-z0-9][a-z0-9.+-]+$`); other values raise an error
#'   to prevent injection into the generated apt-get RUN.
#' @param github_pat character. How to provide a GitHub PAT to
#'   `remotes::install_github()` for private dependency repositories.
#'   One of `"none"` (default; the generated Dockerfile does not
#'   reference any PAT), `"build_arg"` (emit `ARG GITHUB_PAT` + `ENV`
#'   propagation; pass with `--build-arg GITHUB_PAT=$GITHUB_PAT`; the
#'   PAT will be visible in the image metadata), or `"secret"`
#'   (BuildKit secret mount on each `install_github()` / `install_local()`
#'   RUN; the PAT is never persisted in the image; requires BuildKit, so
#'   pass with
#'   `DOCKER_BUILDKIT=1 docker build --secret id=github_pat,env=GITHUB_PAT ...`).
#' @param strict_install boolean. When `TRUE` (the default), every
#'   install RUN in the generated Dockerfile is prefixed with
#'   `options(warn = 2);` so that any R warning during install
#'   (missing CRAN package, partial download, archived package,
#'   404 on a remote) becomes a hard error and aborts the docker
#'   build. Set to `FALSE` if your build environment routinely emits
#'   benign warnings (locale defaulting, NTP time-verification,
#'   ABI-version notices) that you do not want to fail the build.
#'   Must be a single scalar logical; `NA`, character, numeric,
#'   `NULL` and length-2+ vectors are rejected with an error.
#'
#' @export
#' @rdname dockerfiles
#'
#' @importFrom utils installed.packages packageVersion
#' @importFrom remotes dev_package_deps
#' @importFrom desc desc_get_deps desc_get
#' @importFrom usethis use_build_ignore
#' @importFrom pkgbuild build
#'
#' @return Dockerfile
dock_from_desc <- function(
  path = "DESCRIPTION",
  FROM = paste0(
    "rocker/r-ver:",
    R.Version()$major,
    ".",
    R.Version()$minor
  ),
  AS = NULL,
  sysreqs = TRUE,
  repos = c(CRAN = "https://cran.rstudio.com/"),
  expand = FALSE,
  update_tar_gz = TRUE,
  build_from_source = TRUE,
  extra_sysreqs = NULL,
  github_pat = c("none", "build_arg", "secret"),
  strict_install = TRUE
) {
  github_pat <- match.arg(github_pat)
  .validate_scalar_logical(strict_install, "strict_install")
  .validate_FROM(FROM)
  .validate_AS(AS)
  .validate_repos(repos)
  .validate_extra_sysreqs(extra_sysreqs)
  path <- fs::path_abs(path)

  packages <- desc_get_deps(path)$package
  packages <- packages[packages != "R"] # remove R
  packages <- packages[!packages %in% base_pkg_] # remove base and recommended

  if (sysreqs) {

    # please wait during system requirement calculation
    cat_bullet(
      "Please wait while we compute system requirements...",
      bullet = "info",
      bullet_col = "green"
    )

    system_requirement <- unique(
      get_sysreqs(
        packages = packages
      )
    )
    cat_green_tick("Done") # TODO animated version ?
  } else {
    system_requirement <- NULL
  }

  sr <- desc::desc_get(
    file = path,
    keys = "SystemRequirements"
  )

  if (length(extra_sysreqs) > 0) {
    system_requirement <- unique(
      c(
        system_requirement,
        extra_sysreqs
      )
    )
  } else if (!is.na(sr)) {
    message(
      paste(
        "The DESCRIPTION file contains the following SystemRequirements: ",
        sr
      )
    )
    message(
      "Please check the created Dockerfile. \n You might needed to add extra sysreqs."
    )
  }

  remotes_deps <- remotes::package_deps(packages)
  packages_on_cran <- intersect(
    remotes_deps$package[remotes_deps$is_cran],
    packages
  )

  packages_not_on_cran <- setdiff(
    packages,
    packages_on_cran
  )

  packages_with_version <- data.frame(
    package = remotes_deps$package,
    installed = remotes_deps$installed,
    stringsAsFactors = FALSE
  )
  packages_with_version <- packages_with_version[
    packages_with_version$package %in% packages_on_cran,
  ]

  packages_on_cran <- set_name(
    packages_with_version$installed,
    packages_with_version$package
  )

  dock <- Dockerfile$new(
    FROM = FROM,
    AS = AS
  )
  .github_pat_setup(dock, github_pat)

  if (length(system_requirement) > 0) {
    if (!expand) {
      dock$RUN(
        paste(
          "apt-get update && apt-get install -y ",
          paste(system_requirement, collapse = " "),
          "&& rm -rf /var/lib/apt/lists/*"
        )
      )
    } else {
      dock$RUN("apt-get update")
      for (sr in system_requirement) {
        dock$RUN(paste("apt-get install -y ", sr))
      }
      dock$RUN("rm -rf /var/lib/apt/lists/*")
    }
  }

  repos_as_character <- repos_as_character(repos)

  dock$RUN("mkdir -p /usr/local/lib/R/etc/ /usr/lib/R/etc/")




  dock$RUN(
    sprintf(
      "echo \"options(repos = %s, download.file.method = 'libcurl', Ncpus = 4)\" | tee /usr/local/lib/R/etc/Rprofile.site | tee /usr/lib/R/etc/Rprofile.site",
      repos_as_character
    )
  )




  strict_prefix <- .r_strict_prefix(strict_install)

  dock$RUN(
    sprintf(
      "R -e '%sinstall.packages(\"remotes\")'",
      strict_prefix
    )
  )

  if (length(packages_on_cran) > 0) {
    ping <- mapply(
      function(dock, ver, nm, strict_prefix) {
        res <- dock$RUN(sprintf(
          "Rscript -e '%sremotes::install_version(\"%s\",upgrade=\"never\", version = %s)'",
          strict_prefix,
          nm,
          ver
        ))
      },
      ver = quote_not_na(packages_on_cran),
      nm = names(packages_on_cran),
      MoreArgs = list(dock = dock, strict_prefix = strict_prefix)
    )
  }

  if (length(packages_not_on_cran) > 0) {
    nn <- as.data.frame(
      do.call(
        rbind,
        lapply(
          remotes_deps$remote[!remotes_deps$is_cran],
          function(.) {
            .[c("repo", "username", "sha")]
          }
        )
      )
    )

    nn <- sprintf(
      "%s/%s@%s",
      nn$username,
      nn$repo,
      nn$sha
    )


    pong <- mapply(
      function(dock, ver, strict_prefix) {
        res <- dock$RUN(
          sprintf(
            "%sRscript -e '%sremotes::install_github(\"%s\")'",
            .github_pat_run_prefix(github_pat),
            strict_prefix,
            ver
          )
        )
      },
      ver = nn,
      MoreArgs = list(dock = dock, strict_prefix = strict_prefix)
    )
  }

  if (!build_from_source) {
    if (update_tar_gz) {
      old_version <- list.files(
        pattern = sprintf("%s_.+.tar.gz", read.dcf(path)[1]),
        full.names = TRUE
      )

      if (length(old_version) > 0) {
        lapply(old_version, file.remove)
        lapply(old_version, unlink, force = TRUE)
        cat_red_bullet(
          sprintf(
            "%s were removed from folder",
            paste(
              old_version,
              collapse = ", "
            )
          )
        )
      }


      if (
        isTRUE(
          requireNamespace(
            "pkgbuild",
            quietly = TRUE
          )
        )
      ) {
        out <- build(
          path = ".",
          dest_path = ".",
          vignettes = FALSE
        )
        use_build_ignore(files = out)
        cat_green_tick(
          sprintf(
            " %s_%s.tar.gz created.",
            read.dcf(path)[1],
            read.dcf(path)[1, ][["Version"]]
          )
        )
      } else {
        stop("please install {pkgbuild}")
      }
    }
    # we use an already built tar.gz file

    dock$COPY(
      from = paste0(read.dcf(path)[1], "_*.tar.gz"),
      to = "/app.tar.gz"
    )
    dock$RUN(
      paste0(
        .github_pat_run_prefix(github_pat),
        "R -e '",
        strict_prefix,
        "remotes::install_local(\"/app.tar.gz\",upgrade=\"never\")'"
      )
    )
    dock$RUN("rm /app.tar.gz")
  } else {
    dock$RUN("mkdir /build_zone")
    dock$ADD(from = ".", to = "/build_zone")
    dock$WORKDIR("/build_zone")
    dock$RUN(
      paste0(
        .github_pat_run_prefix(github_pat),
        "R -e '",
        strict_prefix,
        "remotes::install_local(upgrade=\"never\")'"
      )
    )
    dock$RUN("rm -rf /build_zone")
  }
  # Add a dockerignore
  docker_ignore_add(
    path = dirname(path)
  )

  .github_pat_announce(github_pat)
  dock
}

#' @noRd
repos_as_character <- function(repos) {
  repos_as_character <- paste(
    utils::capture.output(
      dput(repos)
    ),
    collapse = ""
  )

  repos_as_character <- gsub(
    pattern = '\"',
    replacement = "'",
    x = repos_as_character
  )

  repos_as_character
}
