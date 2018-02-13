#' @importFrom glue glue
#' @importFrom attempt warn_if_not

create_dockerfile <- function(FROM = "rocker/r-base", AS = NULL){
  if (is.null(AS)) {
    glue("FROM {FROM}")
  } else {
    glue("FROM {FROM} AS {AS}")
  }

}

add_run <- function(cmd){
  glue("RUN {cmd}")
}

add_add <- function(from, to, force = TRUE){
  if (!force) {
    warn_if_not(normalizePath(from), file.exists, "The file `from` doesn't seem to exists")
    warn_if_not(normalizePath(to), file.exists, "The file `to` doesn't seem to exists.")
  }
  glue("ADD {from} {to}")
}

add_copy <- function(from, to, force = TRUE){
  if (!force) {
    warn_if_not(normalizePath(from), file.exists, "The file `from` doesn't seem to exists")
    warn_if_not(normalizePath(to), file.exists, "The file `to` doesn't seem to exists.")
  }
  glue("COPY {from} {to}")
}

add_workdir <- function(where){
  glue("WORKDIR {where}")
}

add_expose <- function(port){
  warn_if_not(port, is.numeric, "You've entered a character vector")
  glue("EXPOSE {port}")
}

add_volume <- function(volume){
  glue("VOLUME {volume}")
}

add_cmd <- function(cmd){
  glue("CMD {cmd}")
}

add_label <- function(key, value){
  glue('LABEL "{key}"="{value}"')
}

add_env <- function(key, value){
  glue('ENV "{key}"="{value}"')
}

add_entrypoint <- function(cmd){
  glue("ENTRYPOINT {cmd}")
}

add_user <- function(user){
  glue("USER {user}")
}

add_arg <- function(arg){
  glue("ARG {arg}")
}

add_onbuild <- function(cmd){
  glue("ONBUILD {cmd}")
}

add_stopsignal <- function(signal){
  glue("STOPSIGNAL {signal}")
}

add_healthcheck <- function(check){
  glue("HEALTHCHECK {check}")
}

add_shell <- function(shell){
  glue("SHELL {shell}")
}
