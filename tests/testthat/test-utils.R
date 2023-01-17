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
