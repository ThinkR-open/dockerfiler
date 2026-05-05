test_that("r works", {
  a <- r(install.packages("attempt", repo = "http://cran.irsn.fr/"))
  expect_s3_class(a, "glue")
  expect_s3_class(a, "character")
  expect_match(a, "install.packages")
})

test_that("r preserves expressions containing the digit 2 (#95)", {
  # Regression: the previous regex `gsub(" [2,]", " ", code)` was a
  # typo for `{2,}`. It silently deleted any digit 2 or comma that
  # was preceded by a space, producing invalid R.
  out <- r(c(1, 2, 3))
  expect_equal(as.character(out), "R -e 'c(1, 2, 3)'")

  out <- r(seq(1, 20, by = 2))
  expect_equal(as.character(out), "R -e 'seq(1, 20, by = 2)'")
})

test_that("r preserves commas after spaces (#95)", {
  # Same regression bucket: a literal comma after a space (which never
  # happens in deparse() output, but defends against future deparse()
  # behaviour changes) must not be deleted.
  out <- r(install.packages(c("a", "b"), repos = "http://x"))
  expect_match(
    as.character(out),
    'install\\.packages\\(c\\("a", "b"\\), repos = "http://x"\\)'
  )
})

test_that("r collapses runs of multiple spaces from deparse line-wrap (#95)", {
  # On long expressions, deparse() returns multiple indented lines.
  # paste(collapse = " ") then leaves runs of multiple spaces between
  # the joined lines; r() should collapse them to a single space.
  long_call <- r(install.packages(
    c("aaa", "bbb", "ccc", "ddd", "eee", "fff", "ggg", "hhh", "iii",
      "jjj", "kkk", "lll", "mmm", "nnn", "ooo", "ppp"),
    repos = "https://example.com/very/long/path/that/forces/wrap/"
  ))
  # No run of 2+ consecutive spaces should remain.
  expect_false(grepl("  ", as.character(long_call), fixed = TRUE))
})
