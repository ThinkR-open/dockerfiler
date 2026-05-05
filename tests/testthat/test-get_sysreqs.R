test_that("get_sysreqs works", {
  skip_on_cran()
  skip_if(is_rdevel, "Skip R-devel")
  # pak::pkg_sysreqs(sysreqs_platform = "debian") returns no
  # system_packages on macOS hosts, so this function returns
  # character(0) regardless of the input package.
  skip_on_os("mac")
  res <- get_sysreqs(
    c("mongolite"),
    quiet = TRUE
  )
  expect_true(
    length(res) > 0
  )
  expect_true(
    inherits(res, "character")
  )

})
