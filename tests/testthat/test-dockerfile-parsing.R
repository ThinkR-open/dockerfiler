test_that("Dockerfile parsing works", {
  dock_file <- system.file("Dockerfile", package = "dockerfiler")
  parsed <- parse_dockerfile(dock_file)

  expect_identical(
    paste0(parsed$Dockerfile,  collapse = "\n"),
    paste0(readLines(dock_file), collapse = "\n")
  )

})

test_that("parse_dockerfile returns a Dockerfile R6 object", {
  dock_file <- system.file("Dockerfile", package = "dockerfiler")
  parsed <- parse_dockerfile(dock_file)

  expect_s3_class(parsed, "Dockerfile")
  expect_s3_class(parsed, "R6")
  # The parsed object should expose the same R6 mutators as a fresh
  # Dockerfile (so users can append to a parsed file without re-creating).
  expect_true(is.function(parsed$RUN))
  expect_true(is.function(parsed$ADD))
})

test_that("parse_dockerfile keeps a multi-line continuation as one logical instruction", {
  tmp <- tempfile(fileext = ".dockerfile")
  on.exit(unlink(tmp), add = TRUE)
  writeLines(
    c(
      "FROM debian:bookworm",
      "RUN apt-get update && \\",
      "    apt-get install -y \\",
      "    libcurl4-openssl-dev"
    ),
    con = tmp
  )

  parsed <- parse_dockerfile(tmp)

  # Two logical instructions: FROM + the multi-line RUN.
  expect_equal(length(parsed$Dockerfile), 2L)
  expect_match(parsed$Dockerfile[1], "^FROM debian:bookworm$")
  expect_match(parsed$Dockerfile[2], "^RUN apt-get update")
  # The continuation lines must remain glued to the RUN instruction.
  expect_match(parsed$Dockerfile[2], "libcurl4-openssl-dev", fixed = TRUE)
})

test_that("parse_dockerfile preserves comment lines as their own logical entries", {
  tmp <- tempfile(fileext = ".dockerfile")
  on.exit(unlink(tmp), add = TRUE)
  writeLines(
    c(
      "FROM alpine:3.19",
      "# install build tools",
      "RUN apk add --no-cache build-base"
    ),
    con = tmp
  )

  parsed <- parse_dockerfile(tmp)

  expect_true(any(grepl("^# install build tools$", parsed$Dockerfile)))
  expect_true(any(grepl("^RUN apk add", parsed$Dockerfile)))
})
