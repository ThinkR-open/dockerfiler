test_that("get_sysreqs works", {
  skip_on_cran()
  skip_if(is_rdevel, "Skip R-devel")
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
