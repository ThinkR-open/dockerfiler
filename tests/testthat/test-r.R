context("test-r.R")

test_that("r works", {
  a <- r(install.packages("attempt", repo = "http://cran.irsn.fr/"))
  expect_is(a, "glue")
  expect_is(a, "character")
  expect_match(a, 'install.packages')
})
