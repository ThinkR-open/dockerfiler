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
#' mounted RUN-by-RUN by [.github_pat_run_prefix()]).
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
#' by [.github_pat_setup()]); the `--mount=type=secret,...,env=GITHUB_PAT`
#' fragment for mode `"secret"`.
#' @noRd
.github_pat_run_prefix <- function(mode) {
  if (identical(mode, "secret")) {
    "--mount=type=secret,id=github_pat,env=GITHUB_PAT "
  } else {
    ""
  }
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
