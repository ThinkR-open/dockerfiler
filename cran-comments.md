## R CMD check results

```
0 errors | 0 warnings | 0 notes
```

(local `R CMD check --as-cran` occasionally surfaces a single
transient NOTE "unable to verify current time" caused by host
clock skew on the build VM; the package itself is unaffected.)

## Test environments

* local Ubuntu 24.04, R 4.5.x: `R CMD check --as-cran` clean.
* GitHub Actions (R-CMD-check workflow), all green on the
  submission HEAD:
  * macOS-latest (release)
  * windows-latest (release)
  * ubuntu-latest (release, devel, oldrel-1)
* `devtools::check_win_devel()`: submitted in parallel with this
  CRAN submission; the win-builder result will follow by email
  and will be forwarded to CRAN if it surfaces anything new.

## Maintainer change

This release changes the maintainer from Colin Fay
(`contact@colinfay.me`) to Vincent Guyader
(`vincent@thinkr.fr`). Both remain listed as authors. The
previous maintainer (Colin Fay) is aware of this submission and
will confirm the maintainer change by replying to the automated
email from CRAN's submission system.

## Major changes since 0.2.6

A focused 0.3.0 release. Headline bullets (full details in
`NEWS.md`):

### Breaking changes

* The vendored copy of `{renv}` (~30,000 lines under
  `inst/vendor/`) is removed. Lockfile parsing now uses
  `{jsonlite}` (already in Imports). The exported
  `dockerfiler::renv` symbol is removed; it was a public-API
  surface only because the vendor pattern required it.
* `dock_from_renv()` defaults to a non-root container user
  (`"rstudio"`) with a defensive `useradd` step, an
  auto-derived `RENV_PATHS_CACHE`, a `chown` of the cache, and
  a `USER` directive emitted right before the `renv::restore()`
  cache-mount RUN. Pass `user = NULL` to opt out and keep the
  previous root behaviour.
* `dock_from_renv()` default `FROM` flips from `"rocker/r-base"`
  (amd64-only) to `"rocker/r-ver"` (multi-arch), with the
  lockfile's R version appended at codegen time. Apple Silicon
  and ARM Linux hosts (Ampere, AWS Graviton) now build
  natively.
* `dock_from_renv()` default `repos` flips from
  `"https://cran.rstudio.com/"` to
  `"https://p3m.dev/cran/latest"` (Posit Public Package
  Manager) with automatic rewrite to the
  `__linux__/$VERSION_CODENAME/` shape so the build pulls
  pre-compiled Linux binaries.

### New features

* `dock_from_desc()` and `dock_from_renv()` gain a
  `github_pat` parameter (`"none"` / `"build_arg"` /
  `"secret"`) for private dependency repositories, with an
  opt-in BuildKit secret-mount mode that does not persist the
  PAT in image metadata.
* `dock_from_desc()` gains a `strict_install` parameter
  (default `TRUE`) which prefixes every install RUN with
  `options(warn = 2);` so any R warning during install
  (missing CRAN package, partial download, archived package,
  404) becomes a hard error and aborts the docker build.
* `dock_from_renv()` gains a `renv_paths_cache` parameter
  (auto-derived from `user` by default) controlling the
  `RENV_PATHS_CACHE` build-arg / ENV / cache-mount target.
* `dock$ARG()` and the internal `add_arg()` helper gain a
  `default` parameter to emit `ARG <name>=<default>` instead
  of `ARG <name>`.

### Security hardening

* `dock_from_desc()` and `dock_from_renv()` validate every
  user-supplied parameter that flows into a Dockerfile shell
  context (`FROM`, `AS`, `repos` values and names,
  `extra_sysreqs`, `renv_version`, `renv_paths_cache`,
  `lockfile` basename, `use_pak`, `strict_install`, `r_version`
  read from the lockfile, `user`). Inputs that contain shell
  metacharacters, newlines, or do not match the documented
  format raise an explicit error at function entry rather than
  silently producing a malformed Dockerfile or one that could
  execute attacker-controlled commands at `docker build` time.

### Bug fixes

* `r()` no longer silently rewrites user code (`gsub("[ ][2,]",
  ...)` typo) and now wraps the deparsed expression with
  `shQuote(., type = "sh")` so apostrophes inside string
  literals no longer break the emitted `R -e '...'` command.
* `dock_from_desc(build_from_source = FALSE)` no longer carries
  a dead-code `if (missing(out))` branch.

## Reverse dependencies

`{golem}` depends on `{dockerfiler}`. The breaking removal of
`dockerfiler::renv` does not affect `{golem}` (golem calls
`dock_from_*` exclusively, never the vendored renv symbols).
`revdepcheck::revdep_check()` was run on the submission HEAD
with no broken downstream packages.

## Other notes

* Test coverage stands at 99.84% (320+ tests). The single
  uncovered line is a defensive `stop()` guard in
  `dock_from_desc()` that fires only when `{pkgbuild}` is not
  installed; since `{pkgbuild}` is in `Imports`, the guard is
  unreachable in normal package use.
* No URLs in the package metadata or vignettes 404 (verified
  with `urlchecker::url_check()` prior to submission).
