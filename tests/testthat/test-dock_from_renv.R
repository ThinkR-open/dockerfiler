
# A temporary directory
dir_build <- tempfile(pattern = "renv")
dir.create(dir_build)

# Create a lockfile
the_lockfile <- file.path(dir_build, "renv.lock")

custom_packages <- c(
  # attachment::att_from_description(),
  "cli",
  "glue", # "golem",
  "shiny",
  "stats",
  "utils",
  "testthat",
  "knitr"
)
try(dockerfiler::renv$initialize(),silent=TRUE)
if ( !testthat:::on_cran()){
dockerfiler::renv$snapshot(
  packages = custom_packages,
  lockfile = the_lockfile,
  prompt = FALSE
) } else {
    file.copy(from = system.file("renv.lock",package = "dockerfiler"),to = the_lockfile)
}

# Modify R version for tests
renv_file <- readLines(file.path(dir_build, "renv.lock"))
renv_file[grep("Version", renv_file)[1]] <- '    "Version": "4.1.2",'
writeLines(renv_file, file.path(dir_build, "renv.lock"))



# dock_from_renv ----
test_that("dock_from_renv works", {

  # testthat::skip_on_cran()
  # skip_if_not(interactive())
  # Create Dockerfile
  skip_if(is_rdevel, "skip on R-devel")

  testthat::with_mocked_bindings(code = {
    out <- dock_from_renv(
      lockfile = the_lockfile,
      FROM = "rocker/verse",
      renv_version = "0.0.0"
    )
  },
  compact_sysreqs = function(...) "fake sys reqs",
  repos_as_character = function(...) "fake repos"
  )

  expect_s3_class(
    out,
    "Dockerfile"
  )
  expect_s3_class(
    out,
    "R6"
  )

  # read Dockerfile
  out$write(
    file.path(
      dir_build,
      "Dockerfile"
    )
  )

  dock_created <- readLines(
    file.path(
      dir_build,
      "Dockerfile"
    )
  )

  dock_expected <- readLines(
    testthat::test_path("renv_Dockerfile")
  )

  expect_equal(dock_created, dock_expected)

  skip_if(is_rdevel, "Skip R-devel")
  #python3 is not a direct dependencies from custom_packages
  expect_false(  any(grepl("python3",out$Dockerfile)))

})
# rstudioapi::navigateToFile(file.path(dir_build, "Dockerfile"))
#
test_that("dock_from_renv works with full dependencies", {
  # testthat::skip_on_cran()
  # skip_if_not(interactive())
  # Create Dockerfile
skip_if(is_rdevel, "skip on R-devel")
  out <- dock_from_renv(
    dependencies = TRUE,
    lockfile = the_lockfile,
    FROM = "rocker/verse",
  )
  expect_s3_class(
    out,
    "Dockerfile"
  )
  expect_s3_class(
    out,
    "R6"
  )
  skip_if(is_rdevel, "Skip R-devel")
  #python3 is  a un-direct dependencies from custom_packages
  expect_true(  any(grepl("python3",out$Dockerfile)))
})
# rstudioapi::navigateToFile(file.path(dir_build, "Dockerfile"))



# repos_as_character ----
test_that("repos_as_character works", {
  out <- dockerfiler:::repos_as_character(
    repos = c(
      RSPM = paste0("https://packagemanager.rstudio.com/all/__linux__/focal/latest"),
      CRAN = "https://cran.rstudio.com/"
    )
  )
  expect_equal(
    out,
    "c(RSPM = 'https://packagemanager.rstudio.com/all/__linux__/focal/latest', CRAN = 'https://cran.rstudio.com/')"
  )
})

# gen_base_image ----
test_that("gen_base_image works", {
  out <- dockerfiler:::gen_base_image(
    r_version = "4.0",
    FROM = "rstudio/r-base"
  )
  expect_equal(out, "rstudio/r-base:4.0")

  out <- dockerfiler:::gen_base_image(
    r_version = "4.0",
    FROM = "rocker/verse"
  )
  expect_equal(out, "rocker/verse:4.0")
})





test_that("dock_from_renv works with specific renv", {

  skip_if(is_rdevel, "skip on R-devel")
  # testthat::skip_on_cran()
the_lockfile1.0.0 <- system.file("renv_with_1.0.0.lock",package = "dockerfiler")

for (lf in list(the_lockfile,the_lockfile1.0.0)){
for (renv_version in list(NULL,"banana","missing")){


  if (!is.null(renv_version) && renv_version == "missing") {
    out <- dock_from_renv(lockfile = lf,
                          FROM = "rocker/verse")
  } else{
    out <- dock_from_renv(
      lockfile = lf,
      FROM = "rocker/verse",
      renv_version = renv_version
    )

  }
socle_install_version <- "remotes::install_version\\(\"renv\", version = \""
  if (lf == the_lockfile &    is.null(renv_version)) {
    test_string <- 'install.packages\\(\"renv\"\\)'
  } else if (lf == the_lockfile1.0.0 & is.null(renv_version)) {
    test_string <- 'install.packages\\(\"renv\"\\)'
  } else if (lf == the_lockfile &  renv_version == "banana") {
    test_string <-  paste0(socle_install_version,"banana"  ,"\"\\)")
  } else if (lf == the_lockfile1.0.0 & renv_version == "banana") {
    test_string <- paste0(socle_install_version,"banana","\"\\)")
  } else if (lf == the_lockfile & renv_version == "missing") {
    test_string <-
      paste0(
        socle_install_version,dockerfiler::renv$the$metadata$version,"\"\\)"
      )
  } else if (lf == the_lockfile1.0.0 & renv_version == "missing") {
    test_string <-paste0(socle_install_version,"1.0.0","\"\\)")
  }

  expect_true( any(   grepl(test_string , out$Dockerfile)    ),
               info = paste(lf," & ",renv_version))

  if (is.null(renv_version)) {
    # When using the latest renv, `remotes` must not be installed at all.
    expect_false(
      any(grepl("remotes", out$Dockerfile)),
      info = paste(lf, " & NULL renv_version => no remotes")
    )
  }

}}




})

test_that("dock_from_renv injects PPM HTTPUserAgent, codename and renv override when repos is PPM", {
  skip_if(is_rdevel, "skip on R-devel")
  out <- dock_from_renv(
    lockfile = the_lockfile,
    FROM = "rocker/verse",
    repos = c(CRAN = "https://packagemanager.posit.co/cran/latest"),
    renv_version = "0.0.0"
  )
  df <- paste(out$Dockerfile, collapse = "\n")
  expect_match(df, "__linux__/\\$VERSION_CODENAME/")
  expect_match(df, "HTTPUserAgent = sprintf\\('R \\(")
  expect_match(df, "\\. /etc/os-release && ")
  expect_match(df, "renv\\.config\\.repos\\.override = c\\(CRAN = '")
  # Lock the UA escape level: the Dockerfile must contain literal
  # `R.Version()\$platform` so bash's `echo "..."` emits a `$` (which R
  # then evaluates correctly in Rprofile.site).
  expect_match(df, "R.Version()\\$platform", fixed = TRUE)
  expect_match(df, "R.Version()\\$arch", fixed = TRUE)
  expect_match(df, "R.Version()\\$os", fixed = TRUE)
})

test_that("dock_from_renv leaves non-PPM repos untouched", {
  skip_if(is_rdevel, "skip on R-devel")
  out <- dock_from_renv(
    lockfile = the_lockfile,
    FROM = "rocker/verse",
    repos = c(CRAN = "https://cran.rstudio.com/"),
    renv_version = "0.0.0"
  )
  df <- paste(out$Dockerfile, collapse = "\n")
  expect_false(any(grepl("__linux__", out$Dockerfile)))
  expect_false(any(grepl("HTTPUserAgent", out$Dockerfile)))
  expect_false(any(grepl("/etc/os-release", out$Dockerfile)))
  expect_false(any(grepl("renv\\.config\\.repos\\.override", out$Dockerfile)))
})

test_that("dock_from_renv preserves user-pinned PPM codename", {
  skip_if(is_rdevel, "skip on R-devel")
  out <- dock_from_renv(
    lockfile = the_lockfile,
    FROM = "rocker/verse",
    repos = c(CRAN = "https://packagemanager.posit.co/cran/__linux__/jammy/latest"),
    renv_version = "0.0.0"
  )
  df <- paste(out$Dockerfile, collapse = "\n")
  expect_match(df, "__linux__/jammy/", fixed = TRUE)
  expect_false(any(grepl("\\$VERSION_CODENAME", out$Dockerfile)))
  expect_match(df, "HTTPUserAgent = sprintf")
  # The override must reference the user-pinned URL, not the codename URL.
  expect_match(
    df,
    "renv.config.repos.override = c(CRAN = 'https://packagemanager.posit.co/cran/__linux__/jammy/latest')",
    fixed = TRUE
  )
})

test_that("dock_from_renv preserves a PPM snapshot-date URL", {
  skip_if(is_rdevel, "skip on R-devel")
  snapshot_url <- "https://packagemanager.posit.co/cran/2024-01-15"
  out <- dock_from_renv(
    lockfile = the_lockfile,
    FROM = "rocker/verse",
    repos = c(CRAN = snapshot_url),
    renv_version = "0.0.0"
  )
  df <- paste(out$Dockerfile, collapse = "\n")
  # The snapshot date must survive (no clobbering to /latest).
  expect_match(df, "cran/2024-01-15", fixed = TRUE)
  expect_false(any(grepl("\\$VERSION_CODENAME", out$Dockerfile)))
  expect_false(any(grepl("/etc/os-release", out$Dockerfile)))
  # The override must reference the user URL, not the codename URL.
  expect_match(
    df,
    sprintf(
      "renv.config.repos.override = c(CRAN = '%s')",
      snapshot_url
    ),
    fixed = TRUE
  )
  # User-Agent is still useful with PPM regardless of URL form.
  expect_match(df, "HTTPUserAgent = sprintf")
})

test_that("dock_from_renv leaves multi-entry repos vectors untouched", {
  skip_if(is_rdevel, "skip on R-devel")
  # The PPM patch is intentionally limited to a single CRAN-keyed PPM URL;
  # multi-entry vectors fall through unmodified (back-compat / no surprises).
  out <- dock_from_renv(
    lockfile = the_lockfile,
    FROM = "rocker/verse",
    repos = c(
      RSPM = "https://packagemanager.posit.co/cran/latest",
      CRAN = "https://cran.rstudio.com/"
    ),
    renv_version = "0.0.0"
  )
  expect_false(any(grepl("__linux__", out$Dockerfile)))
  expect_false(any(grepl("HTTPUserAgent", out$Dockerfile)))
  expect_false(any(grepl("/etc/os-release", out$Dockerfile)))
  expect_false(any(grepl("renv\\.config\\.repos\\.override", out$Dockerfile)))
})

test_that(".patch_rprofile_for_ppm is idempotent", {
  skip_if(is_rdevel, "skip on R-devel")
  out <- dock_from_renv(
    lockfile = the_lockfile,
    FROM = "rocker/verse",
    repos = c(CRAN = "https://packagemanager.posit.co/cran/latest"),
    renv_version = "0.0.0"
  )
  before <- out$Dockerfile
  # Re-applying the helper must be a no-op: each mutation is gated by
  # the absence of its target token.
  dockerfiler:::.patch_rprofile_for_ppm(
    out,
    repos = c(CRAN = "https://packagemanager.posit.co/cran/latest")
  )
  expect_identical(out$Dockerfile, before)
})

test_that("dock_from_renv handles a trailing slash on cran/latest/", {
  skip_if(is_rdevel, "skip on R-devel")
  out <- dock_from_renv(
    lockfile = the_lockfile,
    FROM = "rocker/verse",
    repos = c(CRAN = "https://packagemanager.posit.co/cran/latest/"),
    renv_version = "0.0.0"
  )
  df <- paste(out$Dockerfile, collapse = "\n")
  # Trailing slash must not block the codename rewrite.
  expect_match(df, "__linux__/\\$VERSION_CODENAME/")
  expect_match(df, "HTTPUserAgent = sprintf")
})

test_that("dock_from_renv preserves the user's PPM host on rewrite", {
  skip_if(is_rdevel, "skip on R-devel")
  # rstudio.com (the legacy alias) must not be silently rewritten to
  # posit.co; the user's scheme + host is preserved.
  out <- dock_from_renv(
    lockfile = the_lockfile,
    FROM = "rocker/verse",
    repos = c(CRAN = "https://packagemanager.rstudio.com/cran/latest"),
    renv_version = "0.0.0"
  )
  df <- paste(out$Dockerfile, collapse = "\n")
  expect_match(
    df,
    "packagemanager.rstudio.com/cran/__linux__/$VERSION_CODENAME/latest",
    fixed = TRUE
  )
  expect_false(grepl("packagemanager.posit.co", df, fixed = TRUE))
})

unlink(dir_build, recursive = TRUE)

