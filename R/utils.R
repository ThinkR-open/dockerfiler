set_name <- function(x, y) {
  names(x) <- y
  x
}

#' @importFrom cli cat_bullet
#' @noRd
cat_green_tick <- function(...) {
  cat_bullet(
    ...,
    bullet = "tick",
    bullet_col = "green"
  )
}

#' @importFrom cli cat_bullet
#' @noRd
cat_red_bullet <- function(...) {
  cat_bullet(
    ...,
    bullet = "bullet",
    bullet_col = "red"
  )
}

#' @importFrom cli cat_bullet
#' @noRd
cat_info <- function(...) {
  cat_bullet(
    ...,
    bullet = "arrow_right",
    bullet_col = "grey"
  )
}

#' Add GITHUB_PAT plumbing to a Dockerfile.
#'
#' For mode `"build_arg"`, emits an `ARG GITHUB_PAT` directive (no
#' default) and an `ENV GITHUB_PAT=${GITHUB_PAT}` propagation so any
#' subsequent RUN inherits the value. For `"none"` and `"secret"`, no
#' top-level directive is emitted (in `"secret"` mode the secret is
#' mounted RUN-by-RUN by `.github_pat_run_prefix()`).
#' Side-effects only: modifies `dock` in place.
#' @noRd
.github_pat_setup <- function(dock, mode) {
  if (identical(mode, "build_arg")) {
    dock$ARG("GITHUB_PAT")
    dock$ENV(key = "GITHUB_PAT", value = "${GITHUB_PAT}")
  }
  invisible(NULL)
}

#' BuildKit secret-mount prefix for a RUN that needs `GITHUB_PAT`.
#'
#' Returns a string to prepend to a RUN command body. Empty string for
#' modes `"none"` and `"build_arg"` (the latter relies on the ENV set
#' by `.github_pat_setup()`); a `--mount=type=secret,...` fragment plus
#' a shell `GITHUB_PAT=$(cat ...)` prefix for mode `"secret"`.
#'
#' The file-read pattern (`cat /run/secrets/github_pat`) is preferred
#' over the `--mount=type=secret,...,env=GITHUB_PAT` shortcut because
#' the latter requires Dockerfile frontend `1.6+` (introduced in 2023)
#' and otherwise needs an explicit `# syntax=docker/dockerfile:1.6`
#' header. The file-read pattern works on every BuildKit version that
#' supports `--mount=type=secret` at all.
#' @noRd
.github_pat_run_prefix <- function(mode) {
  if (identical(mode, "secret")) {
    "--mount=type=secret,id=github_pat GITHUB_PAT=$(cat /run/secrets/github_pat) "
  } else {
    ""
  }
}

#' Strict-install prefix for an R / Rscript invocation in a Dockerfile RUN.
#'
#' When `strict_install = TRUE`, returns `"options(warn = 2); "` so
#' that warnings emitted during the install (e.g. a missing CRAN
#' package, a 404 on a remote, a partial install) become hard
#' errors and the docker build aborts. Otherwise an empty string,
#' which preserves the legacy behavior where install warnings did
#' not fail the build.
#' @noRd
.r_strict_prefix <- function(strict_install) {
  # Caller must pass a single TRUE / FALSE; `dock_from_desc()` validates.
  if (strict_install) {
    "options(warn = 2); "
  } else {
    ""
  }
}

#' Validate user-supplied strings that flow into a Dockerfile shell context.
#'
#' These helpers reject inputs that, if interpolated raw, would either
#' break the generated Dockerfile / shell command or allow injection of
#' arbitrary commands at `docker build` time. Each helper raises an
#' error with a clear message naming the offending parameter. `NULL` is
#' accepted where it has a documented meaning (e.g. `renv_paths_cache`,
#' `renv_version`, `extra_sysreqs`, `repos`).
#' @noRd
.validate_FROM <- function(x) {
  if (!is.character(x) || length(x) != 1L || is.na(x)) {
    stop(
      "`FROM` must be a single string, got: ",
      deparse(x)
    )
  }
  # Docker reference grammar permits `<host>[:<port>]/<image>[:<tag>][@sha256:<hex>]`.
  # The host segment may itself contain `:` (port). To keep the regex simple
  # and unambiguous, accept any number of `<segment>` separated by `/` where
  # each segment is alphanumerics + `._-`, optionally followed by `:digits`
  # for the port; then the final segment may carry the `:tag` or `@sha256:`
  # suffix. Shell metacharacters (`$`, `` ` ``, `\\`, quotes, newlines,
  # spaces) remain forbidden by the alphabet alone.
  if (
    !grepl(
      paste0(
        "^",
        "[a-zA-Z0-9][a-zA-Z0-9._-]*(:[0-9]+)?",
        "(/[a-zA-Z0-9][a-zA-Z0-9._-]*)*",
        "(:[a-zA-Z0-9._-]+)?",
        "(@sha256:[a-fA-F0-9]+)?",
        "$"
      ),
      x
    )
  ) {
    stop(
      "`FROM` must be a valid Docker image reference ",
      "(`<host>[:<port>]/<image>[:<tag>][@sha256:<hex>]`; alphanumerics ",
      "plus `._-` per segment; no newlines or shell metacharacters), got: ",
      deparse(x)
    )
  }
  invisible()
}

#' @noRd
.validate_r_version <- function(x) {
  if (!is.character(x) || length(x) != 1L || is.na(x)) {
    stop(
      "`r_version` (read from the lockfile) must be a single string, got: ",
      deparse(x)
    )
  }
  # Accept the four shapes renv records in real lockfiles: stable
  # `X.Y` / `X.Y.Z`, release-candidate `X.Y.Z-RC`, R-devel string
  # `r-devel`, and the historical `X.Y.Z Patched` form. The value is
  # interpolated only into the FROM directive, which `.validate_FROM`
  # gates separately for shell metacharacters; a slightly more
  # permissive `r_version` shape is safe.
  ok <- (
    grepl("^[0-9]+\\.[0-9]+(\\.[0-9]+)?(-[A-Za-z0-9._]+)?$", x) ||
      identical(x, "r-devel") ||
      grepl("^[0-9]+\\.[0-9]+(\\.[0-9]+)? Patched$", x)
  )
  if (!ok) {
    stop(
      "`r_version` (read from the lockfile) must look like an R version ",
      "such as \"4.5\", \"4.5.0\", \"4.5.0-RC\", or \"r-devel\", got: ",
      deparse(x)
    )
  }
  invisible()
}

#' @noRd
.validate_repos <- function(x) {
  if (is.null(x)) {
    return(invisible())
  }
  if (!is.character(x)) {
    stop(
      "`repos` must be a character vector, got: ",
      deparse(x)
    )
  }
  # The validated value lands inside double-quoted shell context
  # (`echo "options(repos = ...)"`). Inside `"..."`, the shell still
  # interprets `$`, `\``, `\\` and `!` (bash history). Reject these
  # explicitly so the validator doubles as an escape primitive for the
  # known wrapper. Parens are also rejected because some shells expand
  # them in alias contexts; the URL grammar tolerates `%28`/`%29`.
  bad <- is.na(x) | !grepl(
    "^https?://[A-Za-z0-9._~:/?#@&*+,;=%-]+$",
    x
  )
  if (any(bad)) {
    stop(
      "`repos` entries must be http(s) URLs containing only ",
      "URL-safe characters (no quotes, parentheses, dollar, ",
      "backtick, backslash, spaces or newlines); invalid: ",
      paste(vapply(x[bad], deparse, character(1)), collapse = ", ")
    )
  }
  # Names are emitted via `dput(repos)`, which wraps R-syntax-unsafe
  # names in backticks. Backticks inside a Dockerfile RUN's outer
  # double-quoted shell context trigger command substitution. Tight
  # regex on names to keep them simple identifiers.
  nms <- names(x)
  if (!is.null(nms)) {
    bad_nms <- is.na(nms) | !grepl("^[A-Za-z][A-Za-z0-9._-]*$", nms)
    if (any(bad_nms)) {
      stop(
        "`names(repos)` must be simple identifiers ",
        "(`^[A-Za-z][A-Za-z0-9._-]*$`); invalid: ",
        paste(vapply(nms[bad_nms], deparse, character(1)), collapse = ", ")
      )
    }
  }
  invisible()
}

#' @noRd
.validate_AS <- function(x) {
  if (is.null(x)) {
    return(invisible())
  }
  if (!is.character(x) || length(x) != 1L || is.na(x)) {
    stop(
      "`AS` must be a single string or NULL, got: ",
      deparse(x)
    )
  }
  if (!grepl("^[a-zA-Z0-9][a-zA-Z0-9._-]*$", x)) {
    stop(
      "`AS` must be a simple build-stage name ",
      "(`^[a-zA-Z0-9][a-zA-Z0-9._-]*$`), got: ",
      deparse(x)
    )
  }
  invisible()
}

#' @noRd
.validate_scalar_logical <- function(x, name) {
  if (
    !is.logical(x) ||
      length(x) != 1L ||
      is.na(x)
  ) {
    stop(
      sprintf("`%s` must be a single `TRUE` or `FALSE`, got: ", name),
      deparse(x)
    )
  }
  invisible()
}

#' @noRd
.validate_extra_sysreqs <- function(x) {
  if (is.null(x)) {
    return(invisible())
  }
  if (!is.character(x)) {
    stop(
      "`extra_sysreqs` must be a character vector, got: ",
      deparse(x)
    )
  }
  bad <- is.na(x) | !grepl("^[a-z0-9][a-z0-9.+-]+$", x)
  if (any(bad)) {
    stop(
      "`extra_sysreqs` entries must be Debian package names ",
      "matching `^[a-z0-9][a-z0-9.+-]+$`; invalid: ",
      paste(vapply(x[bad], deparse, character(1)), collapse = ", ")
    )
  }
  invisible()
}

#' @noRd
.validate_renv_version <- function(x) {
  if (is.null(x)) {
    return(invisible())
  }
  if (!is.character(x) || length(x) != 1L || is.na(x)) {
    stop(
      "`renv_version` must be a single string or NULL, got: ",
      deparse(x)
    )
  }
  if (!grepl("^[0-9]+(\\.[0-9]+){0,3}([-.][a-zA-Z0-9]+)?$", x)) {
    stop(
      "`renv_version` must look like a version string such as ",
      "\"1.0.0\" or \"0.16.0-beta\", got: ",
      deparse(x)
    )
  }
  invisible()
}

#' @noRd
.validate_lockfile <- function(x) {
  if (!is.character(x) || length(x) != 1L || is.na(x)) {
    stop(
      "`lockfile` must be a single path string, got: ",
      deparse(x)
    )
  }
  bn <- basename(x)
  if (!grepl("^[A-Za-z0-9._-]+$", bn)) {
    stop(
      "`lockfile` basename must contain only alphanumerics, dots, ",
      "underscores or hyphens (no spaces or shell metacharacters); ",
      "the COPY directive in the generated Dockerfile would otherwise ",
      "be malformed. Got basename: ",
      deparse(bn)
    )
  }
  invisible()
}

#' @noRd
.validate_pkg_name <- function(x) {
  if (!is.character(x) || length(x) != 1L || is.na(x)) {
    stop(
      "the package name read from the DESCRIPTION must be a single ",
      "string, got: ",
      deparse(x)
    )
  }
  # CRAN package-name grammar: a letter, then letters / digits / dots.
  # `read.dcf()` joins DCF continuation lines with `\n`, so a crafted
  # `Package:` field could otherwise smuggle a newline (and an extra
  # Dockerfile directive) into the `COPY <pkg>_*.tar.gz` line generated
  # for `build_from_source = FALSE`. This grammar excludes whitespace,
  # newlines and every shell / Dockerfile metacharacter.
  if (!grepl("^[a-zA-Z][a-zA-Z0-9.]*$", x)) {
    stop(
      "the package name read from the DESCRIPTION must match the CRAN ",
      "package-name grammar /^[a-zA-Z][a-zA-Z0-9.]*$/ ",
      "(letters, digits and dots only, starting with a letter), got: ",
      deparse(x)
    )
  }
  invisible()
}

#' @noRd
.validate_pkg_names <- function(x) {
  if (length(x) == 0L) {
    return(invisible())
  }
  if (!is.character(x)) {
    stop(
      "the package names read from the DESCRIPTION dependency fields ",
      "must be a character vector, got: ",
      deparse(x)
    )
  }
  # Same CRAN package-name grammar as `.validate_pkg_name()`, applied to
  # every Imports / Depends / Suggests / LinkingTo / Enhances entry.
  # `desc::desc_get_deps()` joins DCF continuation lines with `\n`, so a
  # crafted dependency field could otherwise smuggle a newline (and an
  # extra Dockerfile directive) into the generated
  # `remotes::install_version("<name>", ...)` install RUN.
  bad <- is.na(x) | !grepl("^[a-zA-Z][a-zA-Z0-9.]*$", x)
  if (any(bad)) {
    stop(
      "package names read from the DESCRIPTION dependency fields must ",
      "match the CRAN package-name grammar /^[a-zA-Z][a-zA-Z0-9.]*$/ ",
      "(letters, digits and dots only, starting with a letter); ",
      "invalid: ",
      paste(vapply(x[bad], deparse, character(1)), collapse = ", ")
    )
  }
  invisible()
}

#' @noRd
.validate_renv_paths_cache <- function(x) {
  if (is.null(x)) {
    return(invisible())
  }
  if (!is.character(x) || length(x) != 1L || is.na(x)) {
    stop(
      "`renv_paths_cache` must be a single path string or NULL, got: ",
      deparse(x)
    )
  }
  if (!grepl("^/[A-Za-z0-9._/-]*$", x)) {
    stop(
      "`renv_paths_cache` must be an absolute path containing only ",
      "alphanumerics, dots, slashes, underscores or hyphens ",
      "(`^/[A-Za-z0-9._/-]*$`); shell metacharacters or newlines ",
      "would break the ARG directive. Got: ",
      deparse(x)
    )
  }
  invisible()
}

#' Emit a one-shot reminder describing how the PAT must be supplied at
#' `docker build` time. No-op when mode is `"none"`.
#' @noRd
.github_pat_announce <- function(mode) {
  if (identical(mode, "build_arg")) {
    cat_info(
      "Pass the PAT at build time: ",
      "`docker build --build-arg GITHUB_PAT=$GITHUB_PAT ...` ",
      "(NB: the PAT will be visible in the resulting image metadata; ",
      "use `github_pat = \"secret\"` for published images)."
    )
  } else if (identical(mode, "secret")) {
    cat_info(
      "Pass the PAT at build time: ",
      "`DOCKER_BUILDKIT=1 docker build --secret id=github_pat,env=GITHUB_PAT ...`"
    )
  }
  invisible(NULL)
}
