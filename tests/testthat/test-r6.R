context("test-r6.R")

test_that("R6 creation works", {
  my_dock <- Dockerfile$new()
  expect_is(my_dock, "R6")
  expect_is(my_dock, "Dockerfile")
  my_dock$RUN("mkdir /usr/scripts")
  expect_length(my_dock, 22)
})
