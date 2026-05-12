test_that("utils works", {
  res <- testthat::capture_output({
    cat_green_tick("test")
  })
  expect_true(
    grepl(
      "test",
      res
    )
  )
  res <- testthat::capture_output({
    cat_red_bullet("test")
  })
  expect_true(
    grepl(
      "test",
      res
    )
  )
  res <- testthat::capture_output({
    cat_info("test")
  })
  expect_true(
    grepl(
      "test",
      res
    )
  )
})

test_that(".validate_* helpers reject malformed inputs (type / length / NA guards)", {
  # Each `.validate_*` interpolates its argument into a generated
  # Dockerfile directive, so the type/length/NA guards are part of the
  # security contract -- they must fire, not just the format-regex
  # branch (which is exercised elsewhere via the dock_from_* tests).

  expect_error(dockerfiler:::.validate_FROM(123L), "FROM")
  expect_error(dockerfiler:::.validate_FROM(c("a", "b")), "FROM")
  expect_error(dockerfiler:::.validate_r_version(123L), "single string")
  expect_error(dockerfiler:::.validate_r_version(c("4.5", "4.6")), "single string")
  expect_error(dockerfiler:::.validate_AS(123L), "AS")
  expect_error(dockerfiler:::.validate_AS(c("a", "b")), "AS")
  expect_error(dockerfiler:::.validate_renv_version(123L), "renv_version")
  expect_error(dockerfiler:::.validate_renv_version(c("1.0", "2.0")), "renv_version")
  expect_error(dockerfiler:::.validate_lockfile(123L), "lockfile")
  expect_error(dockerfiler:::.validate_lockfile(c("a", "b")), "lockfile")
  expect_error(dockerfiler:::.validate_pkg_name(123L), "package name")
  expect_error(dockerfiler:::.validate_pkg_name(c("a", "b")), "package name")
  expect_error(dockerfiler:::.validate_pkg_name(NA_character_), "package name")
  expect_error(dockerfiler:::.validate_renv_paths_cache(123L), "renv_paths_cache")
  expect_error(dockerfiler:::.validate_renv_paths_cache(c("/a", "/b")), "renv_paths_cache")

  # `NULL` is accepted by the validators that document a `NULL` default.
  expect_silent(dockerfiler:::.validate_AS(NULL))
  expect_silent(dockerfiler:::.validate_renv_version(NULL))
  expect_silent(dockerfiler:::.validate_renv_paths_cache(NULL))

  # Vector validators: a non-character input must raise; an empty vector
  # is the legitimate "no dependencies" case and must be silent.
  expect_error(dockerfiler:::.validate_repos(123L), "character vector")
  expect_error(dockerfiler:::.validate_extra_sysreqs(123L), "character vector")
  expect_error(dockerfiler:::.validate_pkg_names(123L), "character vector")
  expect_silent(dockerfiler:::.validate_extra_sysreqs(NULL))
  expect_silent(dockerfiler:::.validate_pkg_names(character(0)))

  # Scalar-logical validator: anything that is not a single TRUE/FALSE.
  expect_error(dockerfiler:::.validate_scalar_logical(1L, "x"), "x")
  expect_error(dockerfiler:::.validate_scalar_logical(c(TRUE, FALSE), "x"), "x")
  expect_error(dockerfiler:::.validate_scalar_logical(NA, "x"), "x")
  expect_error(dockerfiler:::.validate_scalar_logical("TRUE", "x"), "x")

  # Format-regex branch of the validators that the dock_from_* tests do
  # not already cover directly.
  expect_error(dockerfiler:::.validate_renv_paths_cache("relative/path"), "renv_paths_cache")
  expect_error(dockerfiler:::.validate_pkg_names(c("ok", "1bad")), "package name")
  expect_silent(dockerfiler:::.validate_pkg_names(c("cli", "glue", "R.utils")))
})
