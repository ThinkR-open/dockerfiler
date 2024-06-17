test_that("get_sysreqs works", {
  skip_on_cran()
  R_USER_CACHE_DIR<-tempfile()
  dir.create(R_USER_CACHE_DIR)
  Sys.setenv("R_USER_CACHE_DIR"=R_USER_CACHE_DIR)
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
