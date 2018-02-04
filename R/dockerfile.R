#' A Dockerfile template
#'
#' @return A dockerfile template
#'
#' @importFrom R6 R6Class
#' @export
#'
#' @examples
#' my_dock <- Dockerfile$new()

Dockerfile <- R6Class("Dockerfile",
                       public = list(
                         Dockerfile = character(),
                         ## Either from a file, or from a character vector
                         initialize = function(FROM = "rocker/r-base"){
                           self$Dockerfile <- create_dockerfile("rocker/r-base")
                         },
                         RUN = function(cmd){
                           self$Dockerfile <- glue('{self$Dockerfile}\n {add_run(cmd)}')
                         },
                         ADD = function(from, to){
                           self$Dockerfile <- glue('{self$Dockerfile}\n {add_add(from, to)}')
                         },
                         COPY = function(from, to){
                           self$Dockerfile <- glue('{self$Dockerfile}\n {add_copy(from, to)}')
                         },
                         WORKDIR = function(where){
                           self$Dockerfile <- glue('{self$Dockerfile}\n {add_workdir(where)}')
                         },
                         EXPOSE = function(port){
                           self$Dockerfile <- glue('{self$Dockerfile}\n {add_expose(port)}')
                         },
                         VOLUME = function(volume){
                           self$Dockerfile <- glue('{self$Dockerfile}\n {add_volume(volume)}')
                         },
                         CMD = function(cmd){
                           self$Dockerfile <- glue('{self$Dockerfile}\n {add_cmd(cmd)}')
                         },
                         LABEL = function(key, value){
                           self$Dockerfile <- glue('{self$Dockerfile}\n {add_label(key, value)}')
                         },
                         ENV = function(key, value){
                           self$Dockerfile <- glue('{self$Dockerfile}\n {add_env(key, value)}')
                         },
                         ENTRYPOINT = function(cmd){
                           self$Dockerfile <- glue('{self$Dockerfile}\n {add_entrypoint(cmd)}')
                         },
                         USER = function(user){
                           self$Dockerfile <- glue('{self$Dockerfile}\n {add_user(user)}')
                         },
                         ARG = function(arg){
                           self$Dockerfile <- glue('{self$Dockerfile}\n {add_arg(arg)}')
                         },
                         ONBUILD = function(cmd){
                           self$Dockerfile <- glue('{self$Dockerfile}\n {add_onbuild(cmd)}')
                         },
                         STOPSIGNAL = function(signal){
                           self$Dockerfile <- glue('{self$Dockerfile}\n {add_stopsignal(signal)}')
                         },
                         HEALTHCHECK = function(check){
                           self$Dockerfile <- glue('{self$Dockerfile}\n {add_healthcheck(check)}')
                         },
                         SHELL = function(shell){
                           self$Dockerfile <- glue('{self$Dockerfile}\n {add_shell(shell)}')
                         },
                         print = function(){
                           cat(self$Dockerfile, sep = '\n')
                         },
                         write = function(as = "Dockerfile"){
                           write(self$Dockerfile, file = as)
                         }

                       ))

