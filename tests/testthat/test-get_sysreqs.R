test_that("get_sysreqs works", {
  skip_on_cran()
  skip_if_not(
    attr(
      curlGetHeaders(
        "https://sysreqs.r-hub.io/pkg/mongolite/linux-x86_64-debian-gcc"
      ),
      "status"
    ) == 200
  )
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
  # Test without internet
  withr::with_envvar(
    c(
      "http_proxy" = "http://proxy:port",
      "http_proxy_user" = "username",
      "https_proxy" = "username",
      "https_proxy_user" = "username",
      "ftp_proxy" = "username"
    ),
    res <- get_sysreqs(
      packages = "mongolite",
      quiet = TRUE,
      batch_n = 30
    )
  )
  expect_equal(
    res,
    ""
  )
})
