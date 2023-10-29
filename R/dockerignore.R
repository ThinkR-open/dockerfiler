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
#' \dontrun{
#'   docker_ignore_add()
#' }
docker_ignore_add <- function(path) {
  path_di <- fs::path(
    path,
    ".dockerignore"
  )

  if (!fs::file_exists(
    path_di
  )) {
    fs::file_create(path_di)

    write_ignore <- function(content) {
      write(content, path_di, append = TRUE)
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

    path_ri <- fs::path(
      path,
      ".Rbuildignore"
    )
    if (fs::file_exists(
      path_ri
    )) {
      write(
        "^\\.dockerignore$",
        path_ri,
        append = TRUE)
      cat_bullet(
        ".dockerignore added to the .Rbuildignore file.",
        bullet = "info",
        bullet_col = "green"
      )
    }
  } else {
    cat_bullet(
      ".dockerignore already present, skipping its creation.",
      bullet = "bullet",
      bullet_col = "red"
    )
  }

  return(invisible(path_di))
}
