dir_build <- tempfile(pattern = "renv")
dir.create(dir_build)

# Create a lockfile
the_lockfile <- file.path(dir_build, "renv.lock")
custom_packages <- c(
  # attachment::att_from_description(),
  "renv",
  "cli", "glue", #"golem",
  "shiny", "stats", "utils",
  "testthat",
  "knitr"
)
renv::snapshot(
  packages = custom_packages,
  lockfile = the_lockfile,
  prompt = FALSE)

# Modify R version for tests
renv_file <- readLines(file.path(dir_build, "renv.lock"))
renv_file[grep("Version", renv_file)[1]] <- '    "Version": "4.1.2",'
writeLines(renv_file, file.path(dir_build, "renv.lock"))

# dock_from_renv ----
test_that("dock_from_renv works", {
  # skip_if_not(interactive())
  # Create Dockerfile
  expect_error(
    dock_from_renv(lockfile = the_lockfile,
                   distro = "focal",
                   FROM = "rocker/verse",
                   out_dir = dir_build
    ), regexp = NA)

  # read Dockerfile
  dock_created <- readLines(file.path(dir_build, "Dockerfile"))
  expect_equal(dock_created[1], "FROM rocker/verse:4.1")
  expect_length(
    grep("RUN R -e \"install.packages\\('renv'\\)\"", dock_created), 1
  )
  expect_length(
    grep("RUN R -e 'renv::restore\\(\\)'", dock_created), 1
  )
  expect_equal(
    dock_created[grep("renv.lock.dock renv.lock", dock_created)],
    paste0("COPY ", dir_build, "/renv.lock.dock renv.lock")
  )
  dock_created[grep("renv.lock.dock renv.lock", dock_created)] <-
    "COPY renv.lock.dock renv.lock"


  # System dependencies are different when build in interactive environment?
  skip_if_not(interactive())
  file.copy(file.path(dir_build, "Dockerfile"), "inst/renv_Dockefile", overwrite = TRUE)
  dock_expected <- readLines(system.file("renv_Dockefile", package = "dockerfiler"))
  dock_expected[grep("renv.lock.dock renv.lock", dock_expected)] <-
    "COPY renv.lock.dock renv.lock"

  expect_equal(dock_created, dock_expected)
})
# rstudioapi::navigateToFile(file.path(dir_build, "Dockerfile"))
unlink(dir_build)

# repos_as_character ----
test_that("repos_as_character works", {
  out <- repos_as_character(
    repos = c(
      RSPM = paste0("https://packagemanager.rstudio.com/all/__linux__/focal/latest"),
      CRAN = "https://cran.rstudio.com/")
  )
  expect_equal(
    out,
    "c(RSPM = 'https://packagemanager.rstudio.com/all/__linux__/focal/latest', CRAN = 'https://cran.rstudio.com/')")
})

# gen_base_image ----
test_that("gen_base_image works", {
  out <- gen_base_image(
    distro = "focal",
    r_version = "4.0",
    FROM = "rstudio/r-base"
  )
  expect_equal(out, "rstudio/r-base:4.0-focal")

  out <- gen_base_image(
    distro = "focal",
    r_version = "4.0",
    FROM = "rocker/verse"
  )
  expect_equal(out, "rocker/verse:4.0")
})
