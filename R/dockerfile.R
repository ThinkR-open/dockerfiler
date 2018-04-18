#' A Dockerfile template
#'
#' @return A dockerfile template
#'
#' @section Methods:
#' \describe{
#'   \item{\code{RUN}}{add a RUN command}
#'   \item{\code{ADD}}{add a ADD command}
#'   \item{\code{COPY}}{add a COPY command}
#'   \item{\code{WORKDIR}}{add a WORKDIR command}
#'   \item{\code{EXPOSE}}{add an EXPOSE command}
#'   \item{\code{VOLUME}}{add a VOLUME command}
#'   \item{\code{CMD}}{add a CMD command}
#'   \item{\code{LABEL}}{add a LABEL command}
#'   \item{\code{ENV}}{add a ENV command}
#'   \item{\code{ENTRYPOINT}}{add a ENTRYPOINT command}
#'   \item{\code{VOLUME}}{add a VOLUME command}
#'   \item{\code{USER}}{add a USER command}
#'   \item{\code{ARG}}{add an ARG command}
#'   \item{\code{ONBUILD}}{add a ONBUILD command}
#'   \item{\code{STOPSIGNAL}}{add a STOPSIGNAL command}
#'   \item{\code{HEALTHCHECK}}{add a HEALTHCHECK command}
#'   \item{\code{STOPSIGNAL}}{add a STOPSIGNAL command}
#'   \item{\code{SHELL}}{add a SHELL command}
#'   \item{\code{MAINTAINER}}{add a MAINTAINER command}
#'   \item{\code{custom}}{add a custom command}
#'   \item{\code{write}}{save the Dockerfile}
#'   \item{\code{switch_cmd}}{switch two command}
#'   \item{\code{remove_cmd}}{remove_cmd one or more command(s)}
#' }
#'
#' @importFrom R6 R6Class
#' @export
#'
#' @examples
#' my_dock <- Dockerfile$new()

Dockerfile <- R6::R6Class("Dockerfile",
                      public = list(
                        Dockerfile = character(),
                        ## Either from a file, or from a character vector
                        initialize = function(FROM = "rocker/r-base", AS = NULL){
                          self$Dockerfile <- create_dockerfile(FROM, AS)
                        },
                        RUN = function(cmd){
                          self$Dockerfile <- c(self$Dockerfile, add_run(cmd))
                        },
                        ADD = function(from, to, force = TRUE){
                          self$Dockerfile <- c(self$Dockerfile,add_add(from, to, force))
                        },
                        COPY = function(from, to, force = TRUE){
                          self$Dockerfile <- c(self$Dockerfile,add_copy(from, to, force))
                        },
                        WORKDIR = function(where){
                          self$Dockerfile <- c(self$Dockerfile, add_workdir(where))
                        },
                        EXPOSE = function(port){
                          self$Dockerfile <- c(self$Dockerfile, add_expose(port))
                        },
                        VOLUME = function(volume){
                          self$Dockerfile <- c(self$Dockerfile, add_volume(volume))
                        },
                        CMD = function(cmd){
                          self$Dockerfile <- c(self$Dockerfile, add_cmd(cmd))
                        },
                        LABEL = function(key, value){
                          self$Dockerfile <- c(self$Dockerfile, add_label(key, value))
                        },
                        ENV = function(key, value){
                          self$Dockerfile <- c(self$Dockerfile, add_env(key, value))
                        },
                        ENTRYPOINT = function(cmd){
                          self$Dockerfile <- c(self$Dockerfile, add_entrypoint(cmd))
                        },
                        USER = function(user){
                          self$Dockerfile <- c(self$Dockerfile, add_user(user))
                        },
                        ARG = function(arg, ahead = FALSE){
                          if (ahead) {
                            self$Dockerfile <- c(add_arg(arg), self$Dockerfile)
                          } else {
                            self$Dockerfile <- c(self$Dockerfile,add_arg(arg))
                          }
                        },
                        ONBUILD = function(cmd){
                          self$Dockerfile <- c(self$Dockerfile,add_onbuild(cmd))
                        },
                        STOPSIGNAL = function(signal){
                          self$Dockerfile <- c(self$Dockerfile,add_stopsignal(signal))
                        },
                        HEALTHCHECK = function(check){
                          self$Dockerfile <- c(self$Dockerfile,add_healthcheck(check))
                        },
                        SHELL = function(shell){
                          self$Dockerfile <- c(self$Dockerfile,add_shell(shell))
                        },
                        MAINTAINER = function(name, email){
                          self$Dockerfile <- c(self$Dockerfile,add_maintainer(name, email))
                        },
                        custom = function(base, cmd){
                          self$Dockerfile <- c(self$Dockerfile, add_custom(base, cmd))
                        },
                        print = function(){
                          cat(self$Dockerfile, sep = '\n')
                        },
                        write = function(as = "Dockerfile"){
                          base::write(self$Dockerfile, file = as)
                        },
                        switch_cmd = function(a,b){
                          self$Dockerfile <- switch_them(self$Dockerfile, a, b)
                        },
                        remove_cmd = function(where){
                          self$Dockerfile <- remove_from(self$Dockerfile, where)
                        }
                      ))
