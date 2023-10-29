
#' Parse a Dockerfile
#'
#' Create a Dockerfile object from a Dockerfile.
#'
#' @param path path to the Dockerfile
#' @returns A Dockerfile object
#' @export
#' @examples
#' parse_dockerfile(system.file("Dockerfile", package = "dockerfiler"))
#'
parse_dockerfile <- function(path) {

  # note that MAINTAINER is deprecated but there
  # for backwards compatability
  DOCKER_INSTRUCTIONS <- c(
    "#", # for detecting comments
    # "^$", # to capture empty lines
    "FROM", "RUN", "CMD", "EXPOSE", "LABEL", "MAINTAINER", "EXPOSE", "ENV", "ADD", "COPY", "ENTRYPOINT", "VOLUME", "USER", "WORKDIR", "ARG", "ONBUILD", "STOPSIGNAL", "HEALTHCHECK", "SHELL")

  instruction_regex <- paste0(DOCKER_INSTRUCTIONS, collapse = "|")

  # read the dockerfile
  dock_raw <- readLines(path)
  # capture instructions
  m <- gregexpr(paste0("^", instruction_regex), dock_raw)
  # extract the instruction
  instructions <- unlist(lapply(regmatches(dock_raw, m), `[`, 1))
  # find positions
  instr_pos <- which(!is.na(instructions))
  # find how many lines between instructions and last line
  n_lines_between <- diff(c(instr_pos, length(dock_raw))) - 1
  # the last one needs to add 1
  n_lines_between[length(n_lines_between)] <- n_lines_between[length(n_lines_between)] + 1

  dock_lines <- find_line_positions(dock_raw, instr_pos, instr_pos + n_lines_between)

  res <- Dockerfile$new()
  res$Dockerfile <- dock_lines
  res
}

# helper function to craft commands
find_line_positions <- function(x, start, end) {
  indexes <- Map(seq.int, start, end, by = 1)
  cmnds <- lapply(indexes, function(.x) x[.x])
  vapply(cmnds, paste0, character(1), collapse = "\n")
}
