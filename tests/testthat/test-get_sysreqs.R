test_that("get_sysreqs works", {
  skip_on_cran()
  res <- get_batch_sysreqs(
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
