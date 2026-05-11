# dockerfiler 0.3.0

## Breaking changes

- The vendored copy of `{renv}` (~30,000 lines under `inst/vendor/`)
  is removed. Lockfiles are now parsed with `jsonlite::read_json()`
  (already in Imports). The exported `dockerfiler::renv` symbol is
  removed: it was a public-API surface only because the vendor pattern
  required it. The fallback `renv_version` value, when both the user
  argument is missing and the lockfile does not pin renv, is now
  `NULL` (install the latest renv from the configured repos), aligned
  with the existing `renv_version = NULL` behaviour. Closes #94.
- `dock_from_renv()` now defaults to running the runtime container as
  the `rstudio` user (previously root). The generated Dockerfile gains
  a defensive `RUN id -u rstudio || useradd -m -d /home/rstudio -s /bin/bash rstudio`
  early so the user is created if the FROM image does not already
  ship one (no-op on rocker/* images, real `useradd` on `r-base`,
  `ubuntu:*`, `debian:*`). The renv cache is auto-derived to
  `/home/<user>/.cache/R/renv` and chowned to `<user>` before the
  `USER` directive drops privilege; the `USER` directive itself is
  emitted right before the `renv::restore()` cache-mount RUN, so
  every step that needs root (apt-get, R installs) still runs as
  root. Pass `user = NULL` to opt out and keep the previous root
  behaviour. debian/ubuntu only; for alpine-based images you must
  pass `user = NULL` and create the user yourself. Closes #100.
- `dock_from_renv()` default `FROM` flips from `"rocker/r-base"`
  (amd64-only) to `"rocker/r-ver"` (multi-arch: linux/amd64 +
  linux/arm64), and the R version from the `renv.lock` file is now
  appended at codegen time (e.g. `rocker/r-ver:4.5.0`). Apple
  Silicon and ARM Linux hosts (Ampere, AWS Graviton) now build
  natively without Rosetta. Pass the legacy `FROM = "rocker/r-base"`
  to opt out. Closes #47.
- `dock_from_renv()` default `repos` flips from
  `"https://cran.rstudio.com/"` (source-only CRAN mirror) to
  `"https://p3m.dev/cran/latest"` (Posit Public Package Manager),
  with automatic rewrite to the `__linux__/$VERSION_CODENAME/` shape
  at codegen time so the build pulls pre-compiled Linux binaries
  instead of compiling from source. Build time on packages with
  C/C++ deps drops from minutes to seconds. The PPM rewrite logic
  now matches all three Posit-managed PPM hosts:
  `packagemanager.posit.co`, `packagemanager.rstudio.com`, and
  `p3m.dev`. Pass the legacy
  `repos = c(CRAN = "https://cran.rstudio.com/")` to opt out.
  Closes #57.

## Security

- `dock_from_desc()` and `dock_from_renv()` now validate every
  user-supplied parameter that flows into a Dockerfile shell context
  (`FROM`, `AS`, `repos` values and names, `extra_sysreqs`,
  `renv_version`, `renv_paths_cache`, `lockfile` basename, `use_pak`,
  `strict_install`, plus `r_version` read from the lockfile). Inputs
  that contain shell metacharacters, newlines, or do not match the
  documented format raise an explicit error at function entry,
  rather than silently producing a malformed Dockerfile or one that
  executes attacker-controlled commands at `docker build` time.
  This closes the post-#106 audit follow-up for all five sites
  surfaced by Copilot review.
- Fixed a long-standing code-injection path in `dock_from_renv()`:
  the `renv` package version resolved from the lockfile
  (`lock$Packages$renv$Version`) was interpolated raw into the
  generated `R -e 'remotes::install_version("renv", version = "<x>")'`
  line without passing through `.validate_renv_version()`. A crafted
  `renv.lock` could break out of the inner R string and execute
  arbitrary code as root at `docker build` time. The user-supplied
  `renv_version=` argument has been validated since the 0.3.0
  shell-context hardening above, but the lockfile-fallback path was
  missed; the bug itself predates 0.3.0 (it existed while the
  vendored `{renv}` parser was in use). The validator is now applied
  to the resolved value whatever its source. Found by an internal
  security audit before release.
- Tightened the `.validate_r_version()` "`X.Y.Z Patched`" branch to
  require a single literal space (it previously used `\s`, which in R
  also matches a newline or tab): a lockfile whose `R$Version` carried
  an embedded newline would pass validation and then emit a two-line
  `FROM` directive. Not exploitable for command injection, but it
  could silently break `docker build`.

## New features

- `dock$ARG()` and the internal `add_arg()` helper gain a `default`
  parameter to emit `ARG <name>=<default>` instead of `ARG <name>`.
  Closes #8.
- `dock_from_desc()` and `dock_from_renv()` gain a `github_pat`
  parameter (default `"none"`) controlling how a GitHub PAT is provided
  to `remotes::install_github()` / `remotes::install_local()` /
  `renv::restore()` for private dependency repositories. Set to
  `"build_arg"` to emit `ARG GITHUB_PAT` + `ENV` propagation (passed
  via `--build-arg GITHUB_PAT=$GITHUB_PAT`), or `"secret"` to use
  BuildKit secret mounts (the PAT is never persisted in image
  metadata; recommended for published images). Closes #18.
- `dock_from_renv()` gains a `renv_paths_cache` parameter that
  controls the `RENV_PATHS_CACHE` build-arg default, the propagated
  `ENV` value, and the cache mount target. When `NULL` (the
  default), the path is auto-derived from `user`:
  `/root/.cache/R/renv` for `user = NULL`, and
  `/home/<user>/.cache/R/renv` otherwise. Users can override the
  renv cache location at image build time with
  `--build-arg RENV_PATHS_CACHE=...` without regenerating the
  Dockerfile.
- `dock_from_desc()` gains a `strict_install` parameter (default
  `TRUE`). When `TRUE`, every install RUN in the generated Dockerfile
  is prefixed with `options(warn = 2);` so any R warning during
  install (missing CRAN package, partial download, archived package,
  404 on a remote) becomes a hard error and aborts the docker build.
  This is a behaviour change for users regenerating their Dockerfile:
  install RUNs now refuse to silently swallow warnings. Pass
  `strict_install = FALSE` if your build environment routinely
  emits benign warnings (locale defaulting, NTP time-verification,
  ABI-version notices) that you do not want to fail the build.
  Closes #9.

## Bug fixes

- `r()` no longer silently rewrites user code. The previous
  implementation called `gsub(" [2,]", " ", code)` (a typo for
  `{2,}`) which deleted any digit `2` or comma preceded by a space:
  `r(c(1, 2, 3))` returned `R -e 'c(1, , 3)'`. The replacement
  approach (`gsub("[ ]{2,}", " ", code)`) still collapsed runs of
  spaces inside string literals (`r(cat("a  b"))` would emit
  `R -e 'cat("a b")'`). The fix uses `trimws()` on each `deparse()`
  line then `paste(collapse = " ")`: only the line-wrap indentation
  added by `deparse()` is removed, internal whitespace is preserved.
  Closes #95.
- `r()` now wraps the deparsed R expression with
  `shQuote(., type = "sh")` instead of inlining it inside a hand-rolled
  single-quoted shell string. Apostrophes inside string literals no
  longer break the emitted command: `r(message("don't"))` used to emit
  `R -e 'message("don't")'`, which the shell refuses to parse
  (unterminated quoted string). The new wrapping is shell-safe by
  construction.
- `dock_from_desc(build_from_source = FALSE)` no longer carries
  a dead-code branch (`if (missing(out))`) on the locally-assigned
  result of `pkgbuild::build()`. `missing()` only reports unsupplied
  function arguments, so the branch was unreachable; the success path
  always ran when `build()` returned. The branch is removed; failures
  of `pkgbuild::build()` propagate normally via `stop()`. Closes #98.
- Small polish bundle (no behavioural changes for end users): fix two
  `length(x > 0)` typos in `dock_from_desc()` (intent was
  `length(x) > 0`); drop a duplicate `@export` tag in `dockerignore.R`;
  use the new `dock$ARG(name, default = ...)` form internally instead
  of inlining the `=`; tighten a previously brittle regression test
  that checked for any occurrence of `"remotes"` in the generated
  Dockerfile.


# dockerfiler 0.2.6

- `dock_from_renv()` now auto-configures the generated Dockerfile to fetch
  Linux binaries from Posit Package Manager when `repos` is a single
  CRAN-keyed PPM URL. Four things happen: the PPM URL is rewritten to
  include `__linux__/$VERSION_CODENAME/` (resolved at image build time
  from `/etc/os-release`) when it was `cran` or `cran/latest`;
  `HTTPUserAgent` is set to the strict format PPM requires;
  `renv.config.repos.override` is set so that `renv::restore()` uses PPM
  instead of the lockfile's repo URL; and the RUN is prefixed with
  `. /etc/os-release && ` when the line uses `$VERSION_CODENAME`.
  User-pinned codenames and snapshot-date URLs (e.g. `cran/2024-01-15`)
  are preserved as-is. The user's PPM scheme and host (so a
  `packagemanager.rstudio.com` URL stays on rstudio.com) are preserved
  on rewrite. Non-PPM repos (including internal mirrors not on the
  official PPM hosts) and multi-entry `repos` vectors are left
  untouched.
- `dock_from_renv()` no longer installs `remotes` when `renv_version = NULL`,
  since `remotes` was only needed for the `install_version()` path.


# dockerfiler 0.2.5

- feat: allow multistage dockerfile creation
- feat: COPY function can now specify a stage to copy from. 
- feat: add dedicated cache for `renv::restore`
- feat: add COMMENT function to add comment in Dockerfile thanks to @jcrodriguez1989


# dockerfiler 0.2.4

- remove native pipe thanks to @HenningLorenzen-ext-bayer, this enable to use of older R versions
- update `dock_from_renv()` test to catch all output lines

# dockerfile 0.2.3

- remove sysreqs.r-hub.io to use {pak} instead for system requirement detection
- move from `pak::pkg_system_requirements` to `pak::pkg_sysreqs()` thanks to @B0ydT 
- `dock_from_renv` allow to specify user to use in Dockerfile
- the `dependencies` parameter in `dock_from_renv` if set to `TRUE` will install required dependencies plus optional and development dependencies. defaut is `NA` only required (hard) dependencies,
- Set the minimum version of the {pak} package to 0.6.0. 
- Parameterize the `sysreqs_platform` used to find system dependencies in pkg_sysreqs (only debian/ubuntu based images are supported)


# dockerfiler 0.2.2

- fix : create a `use_pak` parameters in `dock_from_renv` to set `renv.config.pak.enabled = FALSE` instead of `renv.config.pak.enabled = TRUE` to avoid issues with {pak} during `renv::restore()`

- feat: use of {memoise} to cache call to `pak::pkg_system_requirements`

- fix : dont depend anymore  to {renv} use an internalised {renv} version (1.0.3) 

- fix : remove `renv:::lockfile` and use `lockfile_read` instead

- feat: Added `dock_from_renv()`, to create a Dockerfile from a renv.lock file (@JosiahParry, @statnmap)

- feat: Added `parse_dockerfile()`, to Create a Dockerfile object from a Dockerfile file (@JosiahParry)

- feat: Added `renv_version` parameter to `dock_from_renv` to be able to fix the renv version to use during `renv::restore()` (@campbead)


# dockerfiler 0.2.0 

- fix: graceful failing in case no internet

- fix: the dedicated `compact_sysreqs` function allow to deal with 'complex' sysreqs, such as chromimum installation

- feat: add jammy ubuntu distro in available distro

# dockerfiler 0.1.4

* new version of `dock_from_desc()`

# dockerfiler 0.1.3.9000

* Corrected bug in `rthis()`

# dockerfiler 0.1.3

* Added the `add_after()` R6 method
* Added `dock_from_desc()`, to create a Dockerfile from a DESCRIPTION
