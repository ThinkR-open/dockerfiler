# Create a Dockerfile from an `renv.lock` file

Create a Dockerfile from an `renv.lock` file

## Usage

``` r
dock_from_renv(
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
  github_pat = c("none", "build_arg", "secret"),
  renv_paths_cache = "/root/.cache/R/renv"
)
```

## Arguments

- lockfile:

  Path to an `renv.lock` file to use as an input..

- distro:

  - deprecated - only debian/ubuntu based images are supported

- FROM:

  Docker image to start FROM Default is FROM rocker/r-base

- AS:

  The AS of the Dockerfile. Default it `NULL`.

- sysreqs:

  boolean. If `TRUE`, the Dockerfile will contain sysreq installation.

- repos:

  character. The URL(s) of the repositories to use for
  `options("repos")`.

- expand:

  boolean. If `TRUE` each system requirement will have its own `RUN`
  line.

- extra_sysreqs:

  character vector. Extra debian system requirements. Will be installed
  with apt-get install.

- use_pak:

  boolean. If `TRUE` use pak to deal with dependencies during
  [`renv::restore()`](https://rstudio.github.io/renv/reference/restore.html).
  FALSE by default

- user:

  Name of the user to specify in the Dockerfile with the USER
  instruction. Default is `NULL`, in which case the user from the FROM
  image is used.

- dependencies:

  What kinds of dependencies to install. Most commonly one of the
  following values:

  - `NA`: only required (hard) dependencies,

  - `TRUE`: required dependencies plus optional and development
    dependencies,

  - `FALSE`: do not install any dependencies. (You might end up with a
    non-working package, and/or the installation might fail.)

- sysreqs_platform:

  System requirements platform.`ubuntu` by default. If `NULL`, then the
  current platform is used. Can be : "ubuntu-22.04" if needed to fit
  with the `FROM` Operating System. Only debian or ubuntu based images
  are supported

- renv_version:

  character or `NULL`. The renv version to install. The argument has
  three distinct modes, deliberately encoded with the missing-vs-`NULL`
  distinction:

  - **not supplied (default)**: read the renv version from the
    `renv.lock` file. If the lockfile does not pin renv either, the
    latest available version is installed.

  - `NULL` (explicit): always install the latest renv from the
    configured repos, even when the lockfile pins a specific version.

  - a character string such as `"1.0.0"`: install that specific version
    regardless of what the lockfile says.

- github_pat:

  character. How to provide a GitHub PAT to
  [`renv::restore()`](https://rstudio.github.io/renv/reference/restore.html)
  for private dependency repositories. One of `"none"` (default; the
  generated Dockerfile does not reference any PAT), `"build_arg"` (emit
  `ARG GITHUB_PAT` + `ENV` propagation; pass with
  `--build-arg GITHUB_PAT=$GITHUB_PAT`; the PAT will be visible in the
  image metadata), or `"secret"` (BuildKit secret mount on the
  [`renv::restore()`](https://rstudio.github.io/renv/reference/restore.html)
  RUN; the PAT is never persisted in the image; requires BuildKit, so
  pass with
  `DOCKER_BUILDKIT=1 docker build --secret id=github_pat,env=GITHUB_PAT ...`).

- renv_paths_cache:

  character. Path used as the default of the `RENV_PATHS_CACHE`
  build-arg, propagated as an `ENV` variable, and used as the cache
  mount target for
  [`renv::restore()`](https://rstudio.github.io/renv/reference/restore.html).
  Lets users override the renv cache location at image build time via
  `--build-arg RENV_PATHS_CACHE=...`.

## Value

A R6 object of class `Dockerfile`.

## Details

System requirements for packages are provided through RStudio Package
Manager via the pak package. The install commands provided from pak are
added as `RUN` directives within the `Dockerfile`.

The R version is taken from the `renv.lock` file. Packages are installed
using
[`renv::restore()`](https://rstudio.github.io/renv/reference/restore.html)
which ensures that the proper package version and source is used when
installed.

## Examples

``` r
if (FALSE) { # \dontrun{
dock <- dock_from_renv("renv.lock")
dock$write("Dockerfile")
} # }
```
