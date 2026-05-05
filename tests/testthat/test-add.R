test_that("add_add(force = FALSE) warns when source path does not exist", {
  expect_warning(
    out <- dockerfiler:::add_add(
      from = file.path(tempdir(), "definitely-not-a-real-file.xyz"),
      to = "/dest",
      force = FALSE
    ),
    "doesn't seem to exist"
  )
  expect_match(as.character(out), "^ADD ")
})

test_that("add_add(force = TRUE) does not warn even when source is missing", {
  expect_no_warning(
    out <- dockerfiler:::add_add(
      from = "definitely-not-a-real-file.xyz",
      to = "/dest",
      force = TRUE
    )
  )
  expect_match(as.character(out), "^ADD ")
})

test_that("add_copy(force = FALSE) warns when source path does not exist", {
  expect_warning(
    out <- dockerfiler:::add_copy(
      from = file.path(tempdir(), "definitely-not-a-real-file.xyz"),
      to = "/dest",
      force = FALSE
    ),
    "doesn't seem to exist"
  )
  expect_match(as.character(out), "^COPY ")
})

test_that("add_copy with stage = '<name>' emits the COPY --from=<name> form", {
  out <- dockerfiler:::add_copy(
    from = "/src",
    to = "/dest",
    stage = "builder",
    force = TRUE
  )
  expect_equal(as.character(out), "COPY --from=builder /src /dest")
})
