#' Create a dockerignore file
#'
#' @param path Where to write the file
#'
#' @return The path to the `.dockerignore` file, invisibly.
#' @export
#' @importFrom fs path file_exists file_create
#' @importFrom cli cat_bullet
#'
#' @export
#'
#' @examples
#' if (interactive()) {
#'   docker_ignore_add()
#' }
docker_ignore_add <- function(path) {
  path <- fs::path(
    path,
    ".dockerignore"
  )

  if (!fs::file_exists(
    path
  )) {
    fs::file_create(path)

    write_ignore <- function(content) {
      write(content, path, append = TRUE)
    }

    for (i in c(
      ".RData",
      ".Rhistory",
      ".git",
      ".gitignore",
      "manifest.json",
      "rsconnect/",
      ".Rproj.user"
    )) {
      write_ignore(i)
    }
  } else {
    cat_bullet(
      ".dockerignore already present, skipping its creation.",
      bullet = "bullet",
      bullet_col = "red"
    )
  }

  return(invisible(path))
}