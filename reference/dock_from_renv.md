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
  user = "rstudio",
  dependencies = NA,
  sysreqs_platform = "ubuntu",
  renv_version,
  github_pat = c("none", "build_arg", "secret"),
  renv_paths_cache = NULL
)
```

## Arguments

- lockfile:

  Path to an `renv.lock` file to use as an input. The
  `basename(lockfile)` must be located at the docker build context root
  at `docker build` time, because the generated Dockerfile emits
  `COPY <basename(lockfile)> renv.lock`. Validated as a single string
  whose basename contains only alphanumerics, dots, underscores or
  hyphens (no spaces or shell metacharacters).

- distro:

  - deprecated - only debian/ubuntu based images are supported

- FROM:

  Docker image to start FROM. Default is `"rocker/r-base"`. Validated as
  a Docker image reference (alphanumerics, dot, slash, dash, underscore,
  optional `:tag` and / or `@sha256:<hex>`); other values raise an error
  to prevent shell-metacharacter injection into the generated FROM
  directive.

- AS:

  The AS of the Dockerfile. Default is `NULL`. When non-NULL, validated
  as a simple build-stage name (`^[a-zA-Z0-9][a-zA-Z0-9._-]*$`).

- sysreqs:

  boolean. If `TRUE`, the Dockerfile will contain sysreq installation.

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

- extra_sysreqs:

  character vector. Extra debian system requirements. Will be installed
  with apt-get install. Each entry must be a Debian package name
  (`^[a-z0-9][a-z0-9.+-]+$`); other values raise an error to prevent
  injection into the generated apt-get RUN.

- use_pak:

  boolean. If `TRUE` use pak to deal with dependencies during
  [`renv::restore()`](https://rstudio.github.io/renv/reference/restore.html).
  FALSE by default. Must be a single `TRUE` or `FALSE` (no `NA`, no
  vector).

- user:

  Name of the user the runtime container drops privilege to before the
  [`renv::restore()`](https://rstudio.github.io/renv/reference/restore.html)
  step (and therefore at runtime). Default is `"rstudio"` so the
  generated image runs as a non-root user out of the box, which is the
  recommended security posture.

  The Dockerfile is emitted in two halves: every step that needs root
  (apt-get, R install commands, `chown` of the renv cache) runs first;
  then a `USER <user>` directive drops privilege; then the
  [`renv::restore()`](https://rstudio.github.io/renv/reference/restore.html)
  cache-mount RUN happens.

  To make this work regardless of the FROM image, the package emits a
  defensive
  `RUN id -u <user> >/dev/null 2>&1 || useradd -m -d /home/<user> -s /bin/bash <user>`
  early. On rocker/\* images the `useradd` is a no-op (the user already
  exists); on `r-base`, `ubuntu:*`, `debian:*` it creates the user with
  the standard home directory.

  Pass `user = NULL` to opt out: no `USER` directive is emitted and the
  container runs as root (the previous behaviour). Pass any other string
  to use that user instead of `rstudio`. Custom homes (e.g.
  `/srv/myapp`) require also passing an explicit `renv_paths_cache`.

  debian/ubuntu images only (`useradd` is the standard form); for
  alpine-based images you must pass `user = NULL` and handle user
  creation yourself with the alpine-native `adduser`.

  The argument is validated at codegen time against
  `^[a-zA-Z_][a-zA-Z0-9_-]{0,31}$` (POSIX-style username, max 32 chars,
  no shell metacharacters). Other values raise an error to prevent
  metacharacter injection into the generated `RUN` commands.

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

  When supplied as a string, validated as a version-like token
  (`^[0-9]+(\.[0-9]+){0,3}([-.][a-zA-Z0-9]+)?$`).

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

  character or `NULL`. Path used as the default of the
  `RENV_PATHS_CACHE` build-arg, propagated as an `ENV` variable, and
  used as the cache mount target for
  [`renv::restore()`](https://rstudio.github.io/renv/reference/restore.html).
  Lets users override the renv cache location at image build time via
  `--build-arg RENV_PATHS_CACHE=...`.

  When `NULL` (the default), the cache path is derived from `user`:
  `/root/.cache/R/renv` when `user = NULL`, and
  `/home/<user>/.cache/R/renv` when `user` is a non-root username. Pass
  an explicit string to override the convention (e.g. for custom-home
  users like `user = "myapp"` with home at `/srv/myapp`, pass
  `renv_paths_cache = "/srv/myapp/.cache/R/renv"`).

  In all cases (`user = NULL` excepted), the generated Dockerfile emits
  a single
  `RUN mkdir -p "${RENV_PATHS_CACHE}" && chown -R <user>:<user> "${RENV_PATHS_CACHE}"`
  step right before the `USER <user>` directive so the cache mount
  target is writable from the un-privileged user. The cache path is
  double-quoted at shell expansion time so a build-arg override
  containing whitespace cannot break the command.

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
