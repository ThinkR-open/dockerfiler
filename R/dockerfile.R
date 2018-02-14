#' A Dockerfile template
#'
#' @return A dockerfile template
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
                          self$Dockerfile <- create_dockerfile("rocker/r-base", AS)
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
