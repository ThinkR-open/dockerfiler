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

#' Create a Dockerfile from a DESCRIPTION
#
#' @param path path to the DESCRIPTION file to use as an input.
#' @param FROM The FROM of the Dockerfile. Default is
#'     FROM rocker/r-ver:`R.Version()$major`.`R.Version()$minor`.
#' @param AS The AS of the Dockerfile. Default it NULL.
#' @param sha256 The Digest SHA256 hash corresponding to the chip architecture of the deployment host machine if different than the machine on which the image will be built.
#' @param sysreqs boolean. If TRUE, the Dockerfile will contain sysreq installation.
#' @param repos character. The URL(s) of the repositories to use for `options("repos")`.
#' @param expand boolean. If `TRUE` each system requirement will have its own `RUN` line.
#' @param build_from_source boolean. If `TRUE` no tar.gz is created and
#'     the Dockerfile directly mount the source folder.
#' @param update_tar_gz boolean. If `TRUE` and `build_from_source` is also `TRUE`,
#'     an updated tar.gz is created.
#' @param extra_sysreqs character vector. Extra debian system requirements.
#'    Will be installed with apt-get install.
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
#' @export
dock_from_desc <- function(
  path = "DESCRIPTION",
  FROM = paste0(
    "rocker/r-ver:",
    R.Version()$major,
    ".",
    R.Version()$minor
  ),
  sha256 = NULL,
  AS = NULL,
  use_suggests = TRUE,
  sysreqs = TRUE,
  repos = c(CRAN = "https://cran.rstudio.com/"),
  expand = FALSE,
  update_tar_gz = TRUE,
  build_from_source = TRUE,
  extra_sysreqs = NULL
) {
  path <- fs::path_abs(path)

  packages <- desc_get_deps(path)
  if (!use_suggests)
    packages <- packages[packages$type != "Suggests",]
  packages <- packages$package
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

  # Add SHA for Architecture
  if (!is.null(sha256))
    FROM <- paste0(FROM, "@sha256:", sha256)

  dock <- Dockerfile$new(
    FROM = FROM,
    AS = AS
  )

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




  dock$RUN("R -e 'install.packages(\"remotes\")'")

  if (length(packages_on_cran > 0)) {
    ping <- mapply(
      function(dock, ver, nm) {
        res <- dock$RUN(
          sprintf(
            "Rscript -e 'remotes::install_version(\"%s\",upgrade=\"never\", version = \"%s\")'",
            nm,
            ver
          )
        )
      },
      ver = packages_on_cran,
      nm = names(packages_on_cran),
      MoreArgs = list(dock = dock)
    )
  }

  if (length(packages_not_on_cran > 0)) {
    nn_df <- as.data.frame(
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
      "%s/%s",
      nn_df$username,
      nn_df$repo
    )

    repo_status <- lapply(nn, repo_get)
    ind_private <- sapply(repo_status, function(x) x$visibility == "private") %|0|% FALSE
    if (any(ind_private)) {
      dock$ARG("GITHUB_PAT")
      dock$RUN("GITHUB_PAT=$GITHUB_PAT")
    }


    nn <- sprintf(
      "%s/%s@%s",
      nn_df$username,
      nn_df$repo,
      nn_df$sha
    )


    pong <- mapply(
      function(dock, ver, nm, i) {
        fmt <- "Rscript -e 'remotes::install_github(\"%s\")'"
        if (i)
          fmt <- paste("GITHUB_PAT=$GITHUB_PAT", fmt)
        res <- dock$RUN(
          sprintf(
            fmt,
            ver
          )
        )
      },
      ver = nn,
      i = ind_private,
      MoreArgs = list(dock = dock)
    )
    cat_red_bullet(glue::glue("Must add `--build-arg GITHUB_PAT={remotes:::github_pat()}` to `docker build` call. Note that the GITHUB_PAT will be visible in this image metadata. If uploaded to Docker Hub, the visibility must be set to private to avoid exposing the GITHUB_PAT."))
    dock$custom("#", "Must add `--build-arg GITHUB_PAT=[YOUR GITHUB PAT]` to `docker build` call")
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
        if (missing(out)) {
          cat_red_bullet("Error during tar.gz building")
        } else {
          use_build_ignore(files = out)
          cat_green_tick(
            sprintf(
              " %s_%s.tar.gz created.",
              read.dcf(path)[1],
              read.dcf(path)[1, ][["Version"]]
            )
          )
        }
      } else {
        stop("please install {pkgbuild}")
      }
    }
    # we use an already built tar.gz file

    dock$COPY(
      from = paste0(read.dcf(path)[1], "_*.tar.gz"),
      to = "/app.tar.gz"
    )
    dock$RUN("R -e 'remotes::install_local(\"/app.tar.gz\",upgrade=\"never\")'")
    dock$RUN("rm /app.tar.gz")
  } else {
    dock$RUN("mkdir /build_zone")
    dock$ADD(from = ".", to = "/build_zone")
    dock$WORKDIR("/build_zone")
    run <- "R -e 'remotes::install_local(upgrade=\"never\")'"
    if (any(get0("ind_private", inherits = FALSE)))
      run <- paste("GITHUB_PAT=$GITHUB_PAT", run)
    dock$RUN(run)
    dock$RUN("rm -rf /build_zone")
  }
  # Add a dockerignore
  docker_ignore_add(
    path = dirname(path)
  )

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

#' @noRd
repo_get <- function(repo) {
  jsonlite::fromJSON(suppressMessages(system(glue::glue("curl -H \"Accept: application/vnd.github+json\" -H \"Authorization: token {remotes:::github_pat()}\" https://api.github.com/repos/{repo}"), intern = TRUE)))
}

#' Replace zero-length values in a vector
#' @rdname op-zero-default
#' @param x \code{vctr}
#' @param y \code{object} to replace zero-length values. Must be of same class as x
#'
#' @return \code{vctr}
#' @export
#'
#' @examples
#' c(TRUE, FALSE, logical(0)) %|0|% FALSE
`%|0|%` <- Vectorize(function(x, y) {
  if (rlang::is_empty(x))
    y
  else
    x
})
