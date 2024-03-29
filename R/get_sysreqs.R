#' Get system requirements
#'
#' This function retrieves information about the
#' system requirements using the <https://sysreqs.r-hub.io>
#' API.
#'
#' @param packages character vector. Packages names.
#' @param batch_n numeric. Number of simultaneous packages to ask.
#' @param quiet Boolean. If `TRUE` the function is quiet.
#'
#' @importFrom utils download.file
#' @importFrom jsonlite fromJSON
#' @importFrom remotes package_deps
#'
#' @export
#'
#' @return A vector of system requirements.
get_sysreqs <- function(
  packages,
  quiet = TRUE,
  batch_n = 30
) {
  all_deps <- sort(
    unique(
      c(
        packages,
        unlist(
          remotes::package_deps(packages)$package
        )
      )
    )
  )

  sp <- split(
    all_deps,
    ceiling(
      seq_along(all_deps) / batch_n
    )
  )


  sort(
    unique(
      unname(
        unlist(
          lapply(
            sp,
            function(.x) {
              get_batch_sysreqs(
                .x,
                quiet = quiet
              )
            }
          )
        )
      )
    )
  )
}

#' @importFrom fs file_delete  file_temp
get_batch_sysreqs <- function(
  all_deps,
  quiet = TRUE
) {
  url <- sprintf(
    "https://sysreqs.r-hub.io/pkg/%s/linux-x86_64-debian-gcc",
    paste(all_deps, collapse = ",")
  )
  path <- file_temp()

  # Try to download, may fail if
  # no internet or sysreq unavailable.
  # In that case, we return ""
  is_downloaded <- try(
    {
      suppressWarnings({
        utils::download.file(
          url,
          path,
          mode = "wb",
          quiet = quiet
        )
      })
    },
    silent = TRUE
  )

  if (attempt::is_try_error(is_downloaded)) {
    cat_red_bullet("Unable to query the sysreqs.")
    cat_red_bullet("Possible explanation: no internet connection or sysreqs.r-hub.io is unavailable.")
    out <- ""
  } else {
    out <- jsonlite::fromJSON(path)
  }

  try(
    {
      fs::file_delete(path)
    },
    silent = TRUE
  )

  unique(out[!is.na(out)])
}
