#' A Dockerfile template
#'
#' @export
#' @importFrom R6 R6Class
#' @examples
#' my_dock <- Dockerfile$new()
Dockerfile <- R6::R6Class(
"Dockerfile",
public = list(
#' @field Dockerfile The dockerfile content.
Dockerfile = character(),
#' @description
#' Create a new Dockerfile object.
#' @param FROM The base image.
#' @param AS The name of the image.
#' @return A Dockerfile object.
initialize = function(FROM = "rocker/r-base",
AS = NULL) {
self$Dockerfile <- create_dockerfile(FROM, AS)
},
#' @description
#' Add a RUN command.
#' @param cmd The command to add.
#' @return the Dockerfile object, invisibly.
RUN = function(cmd) {
self$Dockerfile <- c(self$Dockerfile, add_run(cmd))
},
#' @description
#' Add a ADD command.
#' @param from The source file.
#' @param to The destination file.
#' @param force If TRUE, overwrite the destination file.
#' @return the Dockerfile object, invisibly.
ADD = function(from, to, force = TRUE) {
self$Dockerfile <- c(self$Dockerfile, add_add(from, to, force))
},
#' @description
#' Add a COPY command.
#' @param from The source file.
#' @param to The destination file.
#' @param force If TRUE, overwrite the destination file.
#' @param stage Optional. Name of the build stage (e.g., `"builder"`) to copy files from. This corresponds to the `--from=` part in a Dockerfile COPY instruction (e.g., `COPY --from=builder /source /dest`). If `NULL`, the `--from=` argument is omitted.
#' @return the Dockerfile object, invisibly.
COPY = function(from, to, stage= NULL , force = TRUE) {
self$Dockerfile <- c(self$Dockerfile, add_copy(from, to, stage, force))
},
#' @description
#' Add a WORKDIR command.
#' @param where The working directory.
#' @return the Dockerfile object, invisibly.
WORKDIR = function(where) {
self$Dockerfile <- c(self$Dockerfile, add_workdir(where))
},
#' @description
#' Add a EXPOSE command.
#' @param port The port to expose.
#' @return the Dockerfile object, invisibly.
EXPOSE = function(port) {
self$Dockerfile <- c(self$Dockerfile, add_expose(port))
},
#' @description
#' Add a VOLUME command.
#' @param volume The volume to add.
#' @return the Dockerfile object, invisibly.
VOLUME = function(volume) {
self$Dockerfile <- c(self$Dockerfile, add_volume(volume))
},
#' @description
#' Add a CMD command.
#' @param cmd The command to add.
#' @return the Dockerfile object, invisibly.
CMD = function(cmd) {
self$Dockerfile <- c(self$Dockerfile, add_cmd(cmd))
},
#' @description
#' Add a LABEL command.
#' @param key,value The key and value of the label.
#' @return the Dockerfile object, invisibly.
LABEL = function(key, value) {
self$Dockerfile <- c(self$Dockerfile, add_label(key, value))
},
#' @description
#' Add a ENV command.
#' @param key,value The key and value of the label.
#' @return the Dockerfile object, invisibly.
ENV = function(key, value) {
self$Dockerfile <- c(self$Dockerfile, add_env(key, value))
},
#' @description
#' Add a ENTRYPOINT command.
#' @param cmd The command to add.
#' @return the Dockerfile object, invisibly.
ENTRYPOINT = function(cmd) {
self$Dockerfile <- c(self$Dockerfile, add_entrypoint(cmd))
},
#' @description
#' Add a USER command.
#' @param user The user to add.
#' @return the Dockerfile object, invisibly.
USER = function(user) {
self$Dockerfile <- c(self$Dockerfile, add_user(user))
},
#' @description
#' Add a ARG command.
#' @param arg The argument to add.
#' @param ahead If TRUE, add the argument at the beginning of the Dockerfile.
#' @return the Dockerfile object, invisibly.
ARG = function(arg, ahead = FALSE) {
if (ahead) {
self$Dockerfile <- c(add_arg(arg), self$Dockerfile)
} else {
self$Dockerfile <- c(self$Dockerfile, add_arg(arg))
}
},
#' @description
#' Add a ONBUILD command.
#' @param cmd The command to add.
#' @return the Dockerfile object, invisibly.
ONBUILD = function(cmd) {
self$Dockerfile <- c(self$Dockerfile, add_onbuild(cmd))
},
#' @description
#' Add a STOPSIGNAL command.
#' @param signal The signal to add.
#' @return the Dockerfile object, invisibly.
STOPSIGNAL = function(signal) {
self$Dockerfile <- c(self$Dockerfile, add_stopsignal(signal))
},
#' @description
#' Add a HEALTHCHECK command.
#' @param check The check to add.
#' @return the Dockerfile object, invisibly.
HEALTHCHECK = function(check) {
self$Dockerfile <- c(self$Dockerfile, add_healthcheck(check))
},
#' @description
#' Add a SHELL command.
#' @param shell The shell to add.
#' @return the Dockerfile object, invisibly.
SHELL = function(shell) {
self$Dockerfile <- c(self$Dockerfile, add_shell(shell))
},
#' @description
#' Add a MAINTAINER command.
#' @param name,email The name and email of the maintainer.
#' @return the Dockerfile object, invisibly.
MAINTAINER = function(name, email) {
self$Dockerfile <- c(self$Dockerfile, add_maintainer(name, email))
},
#' @description
#' Add a custom command.
#' @param base,cmd The base and command to add.
#' @return the Dockerfile object, invisibly.
custom = function(base, cmd) {
self$Dockerfile <- c(self$Dockerfile, add_custom(base, cmd))
},
#' @description
#' Add a comment.
#' @param comment The comment to add.
#' @return the Dockerfile object, invisibly.
COMMENT = function(comment) {
self$Dockerfile <- c(self$Dockerfile, add_comment(comment))
},
#' @description
#' Print the Dockerfile.
#' @return used for side effect
print = function() {
cat(self$Dockerfile, sep = "\n")
},
#' @description
#' Write the Dockerfile to a file.
#' @param as The file to write to.
#' @param append boolean, if TRUE append to file.
#' @return used for side effect
write = function(as = "Dockerfile", append = FALSE) {
base::write(self$Dockerfile, file = as, append = append)
},
#' @description
#' Switch commands.
#' @param a,b The commands to switch.
#' @return the Dockerfile object, invisibly.
switch_cmd = function(a, b) {
self$Dockerfile <- switch_them(self$Dockerfile, a, b)
},
#' @description
#' Remove a command.
#' @param where The commands to remove.
#' @return the Dockerfile object, invisibly.
remove_cmd = function(where) {
self$Dockerfile <- remove_from(self$Dockerfile, where)
},
#' @description
#' Add a command after another.
#' @param cmd The command to add.
#' @param after Where to add the cmd
#' @return the Dockerfile object, invisibly.
add_after = function(cmd, after) {
self$Dockerfile <- add_to(self$Dockerfile, cmd, after)
}
)
)
