set_name <- function(x, y) {
  names(x) <- y
  x
}

#' @importFrom cli cat_bullet
cat_green_tick <- function(...) {
  cat_bullet(
    ...,
    bullet = "tick",
    bullet_col = "green"
  )
}

#' @importFrom cli cat_bullet
cat_red_bullet <- function(...) {
  cat_bullet(
    ...,
    bullet = "bullet",
    bullet_col = "red"
  )
}

#' @importFrom cli cat_bullet
cat_info <- function(...) {
  cat_bullet(
    ...,
    bullet = "arrow_right",
    bullet_col = "grey"
  )
}
