test_that("r works", {
  a <- r(install.packages("attempt", repo = "http://cran.irsn.fr/"))
  expect_s3_class(a, "glue")
  expect_s3_class(a, "character")
  expect_match(a, "install.packages")
})
