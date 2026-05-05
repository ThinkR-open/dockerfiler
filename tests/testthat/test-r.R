test_that("r works", {
  a <- r(install.packages("attempt", repo = "http://cran.irsn.fr/"))
  expect_s3_class(a, "glue")
  expect_s3_class(a, "character")
  expect_match(a, "install.packages")
})

test_that("r preserves digits and structure", {
  out <- r(c(1, 2, 3))
  expect_equal(as.character(out), "R -e 'c(1, 2, 3)'")

  out <- r(seq(1, 20, by = 2))
  expect_equal(as.character(out), "R -e 'seq(1, 20, by = 2)'")
})

test_that("r preserves spaces inside string literals", {
  out <- r(cat("a  b"))
  expect_equal(as.character(out), 'R -e \'cat("a  b")\'')
})

test_that("r normalises deparse line-wrap indentation on long expressions", {
  long_call <- r(install.packages(
    c("aaa", "bbb", "ccc", "ddd", "eee", "fff", "ggg", "hhh", "iii",
      "jjj", "kkk", "lll", "mmm", "nnn", "ooo", "ppp"),
    repos = "https://example.com/very/long/path/that/forces/wrap/"
  ))
  # Indentation runs from deparse() must collapse to a single space.
  expect_false(grepl("  ", as.character(long_call), fixed = TRUE))
  # And the call must remain valid R when re-parsed.
  unwrapped <- sub("^R -e '(.+)'$", "\\1", as.character(long_call))
  expect_silent(parse(text = unwrapped))
})
