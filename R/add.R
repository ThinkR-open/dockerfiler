#' @importFrom glue glue

create_dockerfile <- function(FROM = "rocker/r-base"){
  glue("FROM {FROM}")
}

add_run <- function(cmd){
  glue("RUN {cmd}")
}

add_add <- function(from, to){
  glue("ADD {from} {to}")
}

add_copy <- function(from, to){
  glue("COPY {from} {to}")
}

add_workdir <- function(where){
  glue("WORKDIR {where}")
}

add_expose <- function(port){
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
