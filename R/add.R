#' @importFrom glue glue
#' @importFrom attempt warn_if_not
#' @noRd
create_dockerfile <- function(
  FROM = "rocker/r-base",
  AS = NULL
) {
  if (is.null(AS)) {
    glue("FROM {FROM}")
  } else {
    glue("FROM {FROM} AS {AS}")
  }
}

add_run <- function(cmd) {
  glue("RUN {cmd}")
}

add_add <- function(
  from,
  to,
  force = TRUE
) {
  if (!force) {
    warn_if_not(
      normalizePath(from),
      file.exists,
      "The file `from` doesn't seem to exists"
    )
  }
  glue("ADD {from} {to}")
}

add_copy <- function(
  from,
  to,
  force = TRUE
) {
  if (!force) {
    warn_if_not(
      normalizePath(from),
      file.exists,
      "The file `from` doesn't seem to exists"
    )
  }
  glue("COPY {from} {to}")
}

add_workdir <- function(where) {
  glue("WORKDIR {where}")
}

add_expose <- function(port) {
  warn_if_not(
    port,
    is.numeric,
    "You've entered a character vector"
  )
  glue("EXPOSE {port}")
}

add_volume <- function(volume) {
  glue("VOLUME {volume}")
}

add_cmd <- function(cmd) {
  glue("CMD {cmd}")
}

add_label <- function(key, value) {
  glue('LABEL "{key}"="{value}"')
}

add_env <- function(key, value) {
  glue('ENV "{key}"="{value}"')
}

add_entrypoint <- function(cmd) {
  glue("ENTRYPOINT {cmd}")
}

add_user <- function(user) {
  glue("USER {user}")
}

add_arg <- function(arg) {
  glue("ARG {arg}")
}

add_onbuild <- function(cmd) {
  glue("ONBUILD {cmd}")
}

add_stopsignal <- function(signal) {
  glue("STOPSIGNAL {signal}")
}

add_healthcheck <- function(check) {
  glue("HEALTHCHECK {check}")
}

add_shell <- function(shell) {
  glue("SHELL {shell}")
}

add_maintainer <- function(name, email) {
  glue("MAINTAINER {name} <{email}>")
}

add_custom <- function(base, cmd) {
  glue("{base} {cmd}")
}


add_comment <- function(comment) {
  paste0("# ", strsplit(comment, "\n")[[1]], collapse = "\n")
}

switch_them <- function(vec, a, b) {
  what <- vec[a]
  whbt <- vec[b]
  vec[b] <- what
  vec[a] <- whbt
  vec
}
remove_from <- function(vec, what) {
  vec[-what]
}

add_to <- function(vec, cmd, after) {
  append(vec, cmd, after)
}
