# Changelog

## dockerfiler 0.3.0

### Breaking changes

- The vendored copy of [renv](https://rstudio.github.io/renv/) (~30,000
  lines under `inst/vendor/`) is removed. Lockfiles are now parsed with
  [`jsonlite::read_json()`](https://jeroen.r-universe.dev/jsonlite/reference/read_json.html)
  (already in Imports). The exported `dockerfiler::renv` symbol is
  removed: it was a public-API surface only because the vendor pattern
  required it. The fallback `renv_version` value, when both the user
  argument is missing and the lockfile does not pin renv, is now `NULL`
  (install the latest renv from the configured repos), aligned with the
  existing `renv_version = NULL` behaviour. Closes
  [\#94](https://github.com/ThinkR-open/dockerfiler/issues/94).
- [`dock_from_renv()`](https://thinkr-open.github.io/dockerfiler/reference/dock_from_renv.md)
  now defaults to running the runtime container as the `rstudio` user
  (previously root). The generated Dockerfile gains a defensive
  `RUN id -u rstudio || useradd -m -d /home/rstudio -s /bin/bash rstudio`
  early so the user is created if the FROM image does not already ship
  one (no-op on rocker/\* images, real `useradd` on `r-base`,
  `ubuntu:*`, `debian:*`). The renv cache is auto-derived to
  `/home/<user>/.cache/R/renv` and chowned to `<user>` before the `USER`
  directive drops privilege; the `USER` directive itself is emitted
  right before the
  [`renv::restore()`](https://rstudio.github.io/renv/reference/restore.html)
  cache-mount RUN, so every step that needs root (apt-get, R installs)
  still runs as root. Pass `user = NULL` to opt out and keep the
  previous root behaviour. debian/ubuntu only; for alpine-based images
  you must pass `user = NULL` and create the user yourself. Closes
  [\#100](https://github.com/ThinkR-open/dockerfiler/issues/100).

### New features

- `dock$ARG()` and the internal `add_arg()` helper gain a `default`
  parameter to emit `ARG <name>=<default>` instead of `ARG <name>`.
  Closes [\#8](https://github.com/ThinkR-open/dockerfiler/issues/8).
- [`dock_from_desc()`](https://thinkr-open.github.io/dockerfiler/reference/dockerfiles.md)
  and
  [`dock_from_renv()`](https://thinkr-open.github.io/dockerfiler/reference/dock_from_renv.md)
  gain a `github_pat` parameter (default `"none"`) controlling how a
  GitHub PAT is provided to
  [`remotes::install_github()`](https://remotes.r-lib.org/reference/install_github.html)
  /
  [`remotes::install_local()`](https://remotes.r-lib.org/reference/install_local.html)
  /
  [`renv::restore()`](https://rstudio.github.io/renv/reference/restore.html)
  for private dependency repositories. Set to `"build_arg"` to emit
  `ARG GITHUB_PAT` + `ENV` propagation (passed via
  `--build-arg GITHUB_PAT=$GITHUB_PAT`), or `"secret"` to use BuildKit
  secret mounts (the PAT is never persisted in image metadata;
  recommended for published images). Closes
  [\#18](https://github.com/ThinkR-open/dockerfiler/issues/18).
- [`dock_from_renv()`](https://thinkr-open.github.io/dockerfiler/reference/dock_from_renv.md)
  gains a `renv_paths_cache` parameter (default `/root/.cache/R/renv`)
  used as the build-arg default, the propagated `ENV` value and the
  cache mount target. Users can override the renv cache location at
  image build time with `--build-arg RENV_PATHS_CACHE=...` without
  regenerating the Dockerfile.
- [`dock_from_desc()`](https://thinkr-open.github.io/dockerfiler/reference/dockerfiles.md)
  gains a `strict_install` parameter (default `TRUE`). When `TRUE`,
  every install RUN in the generated Dockerfile is prefixed with
  `options(warn = 2);` so any R warning during install (missing CRAN
  package, partial download, archived package, 404 on a remote) becomes
  a hard error and aborts the docker build. This is a behaviour change
  for users regenerating their Dockerfile: install RUNs now refuse to
  silently swallow warnings. Pass `strict_install = FALSE` if your build
  environment routinely emits benign warnings (locale defaulting, NTP
  time-verification, ABI-version notices) that you do not want to fail
  the build. Closes
  [\#9](https://github.com/ThinkR-open/dockerfiler/issues/9).

### Bug fixes

- [`r()`](https://thinkr-open.github.io/dockerfiler/reference/r.md) no
  longer silently rewrites user code. The previous implementation called
  `gsub(" [2,]", " ", code)` (a typo for `{2,}`) which deleted any digit
  `2` or comma preceded by a space: `r(c(1, 2, 3))` returned
  `R -e 'c(1, , 3)'`. The replacement approach
  (`gsub("[ ]{2,}", " ", code)`) still collapsed runs of spaces inside
  string literals (`r(cat("a b"))` would emit `R -e 'cat("a b")'`). The
  fix uses [`trimws()`](https://rdrr.io/r/base/trimws.html) on each
  [`deparse()`](https://rdrr.io/r/base/deparse.html) line then
  `paste(collapse = " ")`: only the line-wrap indentation added by
  [`deparse()`](https://rdrr.io/r/base/deparse.html) is removed,
  internal whitespace is preserved. Closes
  [\#95](https://github.com/ThinkR-open/dockerfiler/issues/95).
- [`r()`](https://thinkr-open.github.io/dockerfiler/reference/r.md) now
  wraps the deparsed R expression with `shQuote(., type = "sh")` instead
  of inlining it inside a hand-rolled single-quoted shell string.
  Apostrophes inside string literals no longer break the emitted
  command: `r(message("don't"))` used to emit `R -e 'message("don't")'`,
  which the shell refuses to parse (unterminated quoted string). The new
  wrapping is shell-safe by construction.
- `dock_from_desc(build_from_source = FALSE)` no longer carries a
  dead-code branch (`if (missing(out))`) on the locally-assigned result
  of
  [`pkgbuild::build()`](https://pkgbuild.r-lib.org/reference/build.html).
  [`missing()`](https://rdrr.io/r/base/missing.html) only reports
  unsupplied function arguments, so the branch was unreachable; the
  success path always ran when `build()` returned. The branch is
  removed; failures of
  [`pkgbuild::build()`](https://pkgbuild.r-lib.org/reference/build.html)
  propagate normally via [`stop()`](https://rdrr.io/r/base/stop.html).
  Closes [\#98](https://github.com/ThinkR-open/dockerfiler/issues/98).
- Small polish bundle (no behavioural changes for end users): fix two
  `length(x > 0)` typos in
  [`dock_from_desc()`](https://thinkr-open.github.io/dockerfiler/reference/dockerfiles.md)
  (intent was `length(x) > 0`); drop a duplicate `@export` tag in
  `dockerignore.R`; use the new `dock$ARG(name, default = ...)` form
  internally instead of inlining the `=`; tighten a previously brittle
  regression test that checked for any occurrence of `"remotes"` in the
  generated Dockerfile.

## dockerfiler 0.2.6

- [`dock_from_renv()`](https://thinkr-open.github.io/dockerfiler/reference/dock_from_renv.md)
  now auto-configures the generated Dockerfile to fetch Linux binaries
  from Posit Package Manager when `repos` is a single CRAN-keyed PPM
  URL. Four things happen: the PPM URL is rewritten to include
  `__linux__/$VERSION_CODENAME/` (resolved at image build time from
  `/etc/os-release`) when it was `cran` or `cran/latest`;
  `HTTPUserAgent` is set to the strict format PPM requires;
  `renv.config.repos.override` is set so that
  [`renv::restore()`](https://rstudio.github.io/renv/reference/restore.html)
  uses PPM instead of the lockfile’s repo URL; and the RUN is prefixed
  with `. /etc/os-release &&` when the line uses `$VERSION_CODENAME`.
  User-pinned codenames and snapshot-date URLs (e.g. `cran/2024-01-15`)
  are preserved as-is. The user’s PPM scheme and host (so a
  `packagemanager.rstudio.com` URL stays on rstudio.com) are preserved
  on rewrite. Non-PPM repos (including internal mirrors not on the
  official PPM hosts) and multi-entry `repos` vectors are left
  untouched.
- [`dock_from_renv()`](https://thinkr-open.github.io/dockerfiler/reference/dock_from_renv.md)
  no longer installs `remotes` when `renv_version = NULL`, since
  `remotes` was only needed for the `install_version()` path.

## dockerfiler 0.2.5

CRAN release: 2025-05-07

- feat: allow multistage dockerfile creation
- feat: COPY function can now specify a stage to copy from.
- feat: add dedicated cache for
  [`renv::restore`](https://rstudio.github.io/renv/reference/restore.html)
- feat: add COMMENT function to add comment in Dockerfile thanks to
  [@jcrodriguez1989](https://github.com/jcrodriguez1989)

## dockerfiler 0.2.4

CRAN release: 2024-08-23

- remove native pipe thanks to
  [@HenningLorenzen-ext-bayer](https://github.com/HenningLorenzen-ext-bayer),
  this enable to use of older R versions
- update
  [`dock_from_renv()`](https://thinkr-open.github.io/dockerfiler/reference/dock_from_renv.md)
  test to catch all output lines

## dockerfiler 0.2.2

CRAN release: 2023-11-13

- fix : create a `use_pak` parameters in `dock_from_renv` to set
  `renv.config.pak.enabled = FALSE` instead of
  `renv.config.pak.enabled = TRUE` to avoid issues with {pak} during
  [`renv::restore()`](https://rstudio.github.io/renv/reference/restore.html)

- feat: use of {memoise} to cache call to
  [`pak::pkg_system_requirements`](https://pak.r-lib.org/reference/local_system_requirements.html)

- fix : dont depend anymore to {renv} use an internalised {renv} version
  (1.0.3)

- fix : remove `renv:::lockfile` and use `lockfile_read` instead

- feat: Added
  [`dock_from_renv()`](https://thinkr-open.github.io/dockerfiler/reference/dock_from_renv.md),
  to create a Dockerfile from a renv.lock file
  ([@JosiahParry](https://github.com/JosiahParry),
  [@statnmap](https://github.com/statnmap))

- feat: Added
  [`parse_dockerfile()`](https://thinkr-open.github.io/dockerfiler/reference/parse_dockerfile.md),
  to Create a Dockerfile object from a Dockerfile file
  ([@JosiahParry](https://github.com/JosiahParry))

- feat: Added `renv_version` parameter to `dock_from_renv` to be able to
  fix the renv version to use during
  [`renv::restore()`](https://rstudio.github.io/renv/reference/restore.html)
  ([@campbead](https://github.com/campbead))

## dockerfiler 0.2.0

CRAN release: 2022-07-06

- fix: graceful failing in case no internet

- fix: the dedicated `compact_sysreqs` function allow to deal with
  ‘complex’ sysreqs, such as chromimum installation

- feat: add jammy ubuntu distro in available distro

## dockerfiler 0.1.4

CRAN release: 2021-09-03

- new version of
  [`dock_from_desc()`](https://thinkr-open.github.io/dockerfiler/reference/dockerfiles.md)

## dockerfiler 0.1.3.9000

- Corrected bug in `rthis()`

## dockerfiler 0.1.3

CRAN release: 2019-03-19

- Added the `add_after()` R6 method
- Added
  [`dock_from_desc()`](https://thinkr-open.github.io/dockerfiler/reference/dockerfiles.md),
  to create a Dockerfile from a DESCRIPTION
