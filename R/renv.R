
#
# renv 1.0.3 [rstudio/renv#e49d9be]: A dependency management toolkit for R.
# Generated using `renv:::vendor()` at 2023-11-05 11:48:15.
#


#' Internalised {renv}
#'
#' https://rstudio.github.io/renv/reference/vendor.html?q=vendor
#'
#' @export
#' @name renv
#' @alias renv
#' @docType environment
renv <- new.env(parent = new.env())

renv$initialize <- function() {

  # set up renv + imports environments
  attr(renv, "name") <- "embedded:renv"
  attr(parent.env(renv), "name") <- "imports:renv"

  # get imports
  imports <- list(
    tools = c(
      "file_ext",
      "pskill",
      "psnice",
      "write_PACKAGES"
    ),
    utils = c(
      "Rprof",
      "URLencode",
      "adist",
      "available.packages",
      "browseURL",
      "citation",
      "contrib.url",
      "download.file",
      "download.packages",
      "file.edit",
      "getCRANmirrors",
      "head",
      "help",
      "install.packages",
      "installed.packages",
      "modifyList",
      "old.packages",
      "packageDescription",
      "packageVersion",
      "read.table",
      "remove.packages",
      "sessionInfo",
      "str",
      "summaryRprof",
      "tail",
      "tar",
      "toBibtex",
      "untar",
      "unzip",
      "update.packages",
      "zip"
    )
  )

  # load the imports required by renv
  for (package in names(imports)) {
    namespace <- asNamespace(package)
    functions <- imports[[package]]
    list2env(mget(functions, envir = namespace), envir = parent.env(renv))
  }

  # source renv into the aforementioned environment
  script <- system.file("vendor/renv.R", package = .packageName)
  sys.source(script, envir = renv)

  # initialize metadata
  renv$the$metadata <- list(
    embedded = TRUE,
    version = structure("1.0.3", sha = "e49d9be9528e0ff73b673f97382731c140013474")
  )

  # run our load / attach hooks so internal state is initialized
  renv$renv_zzz_load()

  # remove our initialize method when we're done
  rm(list = "initialize", envir = renv)

}
# renv$initialize()
