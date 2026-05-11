
#' @importFrom memoise memoise
#' @noRd
pkg_sysreqs_mem <- memoise::memoise(
    pak::pkg_sysreqs
)


#' Create a Dockerfile from an `renv.lock` file
#'
#' @param lockfile Path to an `renv.lock` file to use as an input.
#'   The `basename(lockfile)` must be located at the docker build
#'   context root at `docker build` time, because the generated
#'   Dockerfile emits `COPY <basename(lockfile)> renv.lock`. Validated
#'   as a single string whose basename contains only alphanumerics,
#'   dots, underscores or hyphens (no spaces or shell metacharacters).
#' @param FROM Docker image to start FROM. Default is `"rocker/r-ver"`,
#'   which is multi-arch (linux/amd64 + linux/arm64) and gets the
#'   lockfile's R version appended at codegen time (e.g.
#'   `rocker/r-ver:4.5.0`). Pass an already-tagged or
#'   already-digested reference (`rocker/r-ver:4.4.1`,
#'   `rocker/r-base@sha256:...`) to override the auto-tag; the user's
#'   tag is honoured verbatim, even if it differs from the lockfile's
#'   `R$Version`. R-devel and release-candidate users whose lockfile
#'   records `r-devel` or `4.5.0-RC` may want to pass an explicit
#'   tag like `FROM = "rocker/r-ver:devel"` to control which base
#'   image is pulled.
#'   Validated as a Docker image reference
#'   (`<host>[:<port>]/<image>[:<tag>][@sha256:<hex>]`); other values
#'   raise an error to prevent shell-metacharacter injection into the
#'   generated FROM directive.
#' @param AS The AS of the Dockerfile. Default is `NULL`. When non-NULL,
#'   validated as a simple build-stage name (`^[a-zA-Z0-9][a-zA-Z0-9._-]*$`).
#' @param distro - deprecated - only debian/ubuntu based images are supported
#' @param sysreqs boolean. If `TRUE`, the Dockerfile will contain sysreq installation.
#' @param expand boolean. If `TRUE` each system requirement will have its own `RUN` line.
#' @param repos character. The URL(s) of the repositories to use for
#'   `options("repos")`. Default is
#'   `c(CRAN = "https://p3m.dev/cran/latest")` (Posit Public Package
#'   Manager). When the URL is recognized as a PPM host
#'   (`packagemanager.posit.co`, `packagemanager.rstudio.com`, or
#'   `p3m.dev`), the codegen rewrites it to the
#'   `__linux__/$VERSION_CODENAME/` shape so the build pulls Linux
#'   binaries (5-10x faster than building from source). Each value
#'   must look like an http(s) URL (no quotes, spaces or newlines);
#'   each name (when set) must be a simple identifier
#'   (`^[A-Za-z][A-Za-z0-9._-]*$`). Other values raise an error to
#'   prevent injection into the generated `echo "options(...)"` shell
#'   command.
#' @param extra_sysreqs character vector. Extra debian system requirements.
#'   Will be installed with apt-get install. Each entry must be a Debian
#'   package name (`^[a-z0-9][a-z0-9.+-]+$`); other values raise an error
#'   to prevent injection into the generated apt-get RUN.
#' @param renv_version character or `NULL`. The renv version to install.
#'   The argument has three distinct modes, deliberately encoded with
#'   the missing-vs-`NULL` distinction:
#'   - **not supplied (default)**: read the renv version from the
#'     `renv.lock` file. If the lockfile does not pin renv either,
#'     the latest available version is installed.
#'   - `NULL` (explicit): always install the latest renv from the
#'     configured repos, even when the lockfile pins a specific
#'     version.
#'   - a character string such as `"1.0.0"`: install that specific
#'     version regardless of what the lockfile says.
#'
#'   When supplied as a string, validated as a version-like token
#'   (`^[0-9]+(\.[0-9]+){0,3}([-.][a-zA-Z0-9]+)?$`).
#' @param use_pak boolean. If `TRUE` use pak to deal with dependencies
#'   during `renv::restore()`. FALSE by default. Must be a single
#'   `TRUE` or `FALSE` (no `NA`, no vector).
#' @param user Name of the user the runtime container drops privilege
#'   to before the `renv::restore()` step (and therefore at runtime).
#'   Default is `"rstudio"` so the generated image runs as a non-root
#'   user out of the box, which is the recommended security posture.
#'
#'   The Dockerfile is emitted in two halves: every step that needs
#'   root (apt-get, R install commands, `chown` of the renv cache)
#'   runs first; then a `USER <user>` directive drops privilege; then
#'   the `renv::restore()` cache-mount RUN happens.
#'
#'   To make this work regardless of the FROM image, the package
#'   emits a defensive `RUN id -u <user> >/dev/null 2>&1 ||
#'   useradd -m -d /home/<user> -s /bin/bash <user>` early. On
#'   rocker/* images the `useradd` is a no-op (the user already
#'   exists); on `r-base`, `ubuntu:*`, `debian:*` it creates the user
#'   with the standard home directory.
#'
#'   Pass `user = NULL` to opt out: no `USER` directive is emitted
#'   and the container runs as root (the previous behaviour).
#'   Pass any other string to use that user instead of `rstudio`.
#'   Custom homes (e.g. `/srv/myapp`) require also passing an
#'   explicit `renv_paths_cache`.
#'
#'   debian/ubuntu images only (`useradd` is the standard form);
#'   for alpine-based images you must pass `user = NULL` and handle
#'   user creation yourself with the alpine-native `adduser`.
#'
#'   The argument is validated at codegen time against
#'   `^[a-zA-Z_][a-zA-Z0-9_-]{0,31}$` (POSIX-style username, max 32
#'   chars, no shell metacharacters). Other values raise an error
#'   to prevent metacharacter injection into the generated `RUN`
#'   commands.
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
#' @param renv_paths_cache character or `NULL`. Path used as the
#'   default of the `RENV_PATHS_CACHE` build-arg, propagated as an
#'   `ENV` variable, and used as the cache mount target for
#'   `renv::restore()`. Lets users override the renv cache location
#'   at image build time via `--build-arg RENV_PATHS_CACHE=...`.
#'
#'   When `NULL` (the default), the cache path is derived from
#'   `user`: `/root/.cache/R/renv` when `user = NULL`, and
#'   `/home/<user>/.cache/R/renv` when `user` is a non-root username.
#'   Pass an explicit string to override the convention (e.g. for
#'   custom-home users like `user = "myapp"` with home at
#'   `/srv/myapp`, pass `renv_paths_cache = "/srv/myapp/.cache/R/renv"`).
#'
#'   In all cases (`user = NULL` excepted), the generated Dockerfile
#'   emits a single `RUN mkdir -p "${RENV_PATHS_CACHE}" && chown -R <user>:<user> "${RENV_PATHS_CACHE}"`
#'   step right before the `USER <user>` directive so the cache mount
#'   target is writable from the un-privileged user. The cache path
#'   is double-quoted at shell expansion time so a build-arg
#'   override containing whitespace cannot break the command.
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
#' dock <- dock_from_renv("renv.lock")
#' dock$write("Dockerfile")
#' }
dock_from_renv <- function(
  lockfile = "renv.lock",
  distro = NULL,
  FROM = "rocker/r-ver",
  AS = NULL,
  sysreqs = TRUE,
  repos = c(CRAN = "https://p3m.dev/cran/latest"),
  expand = FALSE,
  extra_sysreqs = NULL,
  use_pak = FALSE,
  user = "rstudio",
  dependencies = NA,
  sysreqs_platform = "ubuntu",
  renv_version,
  github_pat = c("none", "build_arg", "secret"),
  renv_paths_cache = NULL
) {
  github_pat <- match.arg(github_pat)
  .validate_lockfile(lockfile)
  .validate_FROM(FROM)
  .validate_AS(AS)
  .validate_repos(repos)
  .validate_extra_sysreqs(extra_sysreqs)
  .validate_scalar_logical(use_pak, "use_pak")
  if (!missing(renv_version)) {
    .validate_renv_version(renv_version)
  }
  .validate_renv_paths_cache(renv_paths_cache)
  if (!is.null(user)) {
    # `user` is interpolated into shell commands (id, useradd, chown, USER).
    # Reject anything that is not a strict POSIX username so a caller passing
    # ``"; rm -rf /"`` or ``"bad user"`` cannot inject into / break the
    # generated Dockerfile.
    if (
      !is.character(user) ||
        length(user) != 1L ||
        !grepl("^[a-zA-Z_][a-zA-Z0-9_-]{0,31}$", user)
    ) {
      stop(
        "`user` must be a single string matching the POSIX username ",
        "regex /^[a-zA-Z_][a-zA-Z0-9_-]{0,31}$/, ",
        "got: ",
        deparse(user)
      )
    }
  }
  if (is.null(renv_paths_cache)) {
    renv_paths_cache <- if (is.null(user)) {
      "/root/.cache/R/renv"
    } else {
      sprintf("/home/%s/.cache/R/renv", user)
    }
  }
  lock <- jsonlite::read_json(
    lockfile,
    simplifyVector = TRUE,
    simplifyDataFrame = FALSE,
    simplifyMatrix = FALSE
  )

  # start the dockerfile
  R_major_minor <- lock$R$Version
  .validate_r_version(R_major_minor)
  dock <- Dockerfile$new(
    FROM = gen_base_image(
      r_version = R_major_minor,
      FROM = FROM
    ),
    AS = AS
  )
  if (!is.null(user)) {
    dock$RUN(
      sprintf(
        "id -u %s >/dev/null 2>&1 || useradd -m -d /home/%s -s /bin/bash %s",
        user,
        user,
        user
      )
    )
  }
  .github_pat_setup(dock, github_pat)
  dock$ARG("RENV_PATHS_CACHE", default = renv_paths_cache)
  dock$ENV(key = "RENV_PATHS_CACHE", value = "${RENV_PATHS_CACHE}")
  # USER (if any) is emitted later, after the apt-get / R install steps
  # that need root and after the chown of RENV_PATHS_CACHE.
  # get renv version

  if (missing(renv_version)) {
    # The lockfile is untrusted input: its `Packages$renv$Version` is
    # interpolated into the generated `R -e
    # 'remotes::install_version(...)'` line, which runs as root at
    # `docker build` time. Validate it with the same regex applied to a
    # user-supplied `renv_version` (which is validated at function entry).
    renv_version <- lock$Packages$renv$Version
    if (!is.null(renv_version)) {
      .validate_renv_version(renv_version)
    }
  }

  message("renv version = ",
          ifelse(!is.null(renv_version), renv_version, "the most up to date version in the repos")
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
  if (!is.null(user)) {
    # Drop privilege right before the cache-mount renv::restore RUN.
    # The mkdir + chown make the cache target writable by `user` even
    # though the Docker BuildKit cache mount itself is created on-demand.
    # Single RUN with `&&` keeps the image layer count down and the
    # quoted `"${RENV_PATHS_CACHE}"` survives a build-arg with spaces.
    dock$RUN(
      sprintf(
        'mkdir -p "${RENV_PATHS_CACHE}" && chown -R %s:%s "${RENV_PATHS_CACHE}"',
        user,
        user
      )
    )
    dock$USER(user)
  }
  dock$RUN(
    paste0(
      "--mount=type=cache,id=renv-cache,target=${RENV_PATHS_CACHE} ",
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
  # Match the three current PPM host shapes: the original
  # `packagemanager.rstudio.com`, the rebranded `packagemanager.posit.co`,
  # and the short `p3m.dev` (which Posit started promoting in 2024 as
  # the recommended URL for binary mirrors). Enumerate explicitly to
  # avoid the `(posit|rstudio).(co|com)` Cartesian-product trap that
  # would also accept `posit.com` and `rstudio.co` (neither is a real
  # Posit-managed host).
  ppm_pattern <- paste0(
    "^https?://(",
    "packagemanager\\.posit\\.co|",
    "packagemanager\\.rstudio\\.com|",
    "p3m\\.dev",
    ")/"
  )
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
  # Preserve the user's scheme + host on rewrite (so a
  # `packagemanager.rstudio.com` URL stays on rstudio.com and is not
  # silently swapped to posit.co). The PPM detection regex above only
  # matches the three Posit-managed PPM hosts; non-PPM internal mirrors are
  # not entered into this branch at all.
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

