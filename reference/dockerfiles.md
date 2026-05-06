# Create a Dockerfile from a DESCRIPTION

Create a Dockerfile from a DESCRIPTION

## Usage

``` r
dock_from_desc(
  path = "DESCRIPTION",
  FROM = paste0("rocker/r-ver:", R.Version()$major, ".", R.Version()$minor),
  AS = NULL,
  sysreqs = TRUE,
  repos = c(CRAN = "https://cran.rstudio.com/"),
  expand = FALSE,
  update_tar_gz = TRUE,
  build_from_source = TRUE,
  extra_sysreqs = NULL,
  github_pat = c("none", "build_arg", "secret"),
  strict_install = TRUE
)
```

## Arguments

- path:

  path to the DESCRIPTION file to use as an input.

- FROM:

  The FROM of the Dockerfile. Default is
  `paste0("rocker/r-ver:", R.Version()$major, ".", R.Version()$minor)`.
  Validated as a Docker image reference (alphanumerics, dot, slash,
  dash, underscore, optional `:tag` and / or `@sha256:<hex>`); other
  values raise an error to prevent shell-metacharacter injection into
  the generated FROM directive.

- AS:

  The AS of the Dockerfile. Default it NULL. When non-NULL, validated as
  a simple build-stage name (`^[a-zA-Z0-9][a-zA-Z0-9._-]*$`).

- sysreqs:

  boolean. If TRUE, the Dockerfile will contain sysreq installation.

- repos:

  character. The URL(s) of the repositories to use for
  `options("repos")`. Each value must look like an http(s) URL (no
  quotes, spaces or newlines); each name (when set) must be a simple
  identifier (`^[A-Za-z][A-Za-z0-9._-]*$`). Other values raise an error
  to prevent injection into the generated `echo "options(...)"` shell
  command.

- expand:

  boolean. If `TRUE` each system requirement will have its own `RUN`
  line.

- update_tar_gz:

  boolean. If `TRUE` and `build_from_source` is also `TRUE`, an updated
  tar.gz is created.

- build_from_source:

  boolean. If `TRUE` no tar.gz is created and the Dockerfile directly
  mount the source folder.

- extra_sysreqs:

  character vector. Extra debian system requirements. Will be installed
  with apt-get install. Each entry must be a Debian package name
  (`^[a-z0-9][a-z0-9.+-]+$`); other values raise an error to prevent
  injection into the generated apt-get RUN.

- github_pat:

  character. How to provide a GitHub PAT to
  [`remotes::install_github()`](https://remotes.r-lib.org/reference/install_github.html)
  for private dependency repositories. One of `"none"` (default; the
  generated Dockerfile does not reference any PAT), `"build_arg"` (emit
  `ARG GITHUB_PAT` + `ENV` propagation; pass with
  `--build-arg GITHUB_PAT=$GITHUB_PAT`; the PAT will be visible in the
  image metadata), or `"secret"` (BuildKit secret mount on each
  `install_github()` / `install_local()` RUN; the PAT is never persisted
  in the image; requires BuildKit, so pass with
  `DOCKER_BUILDKIT=1 docker build --secret id=github_pat,env=GITHUB_PAT ...`).

- strict_install:

  boolean. When `TRUE` (the default), every install RUN in the generated
  Dockerfile is prefixed with `options(warn = 2);` so that any R warning
  during install (missing CRAN package, partial download, archived
  package, 404 on a remote) becomes a hard error and aborts the docker
  build. Set to `FALSE` if your build environment routinely emits benign
  warnings (locale defaulting, NTP time-verification, ABI-version
  notices) that you do not want to fail the build. Must be a single
  scalar logical; `NA`, character, numeric, `NULL` and length-2+ vectors
  are rejected with an error.

## Value

Dockerfile
