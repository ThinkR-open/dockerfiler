test_that("Dockerfile parsing works", {
  dock_file <- system.file("Dockerfile", package = "dockerfiler")
  parsed <- parse_dockerfile(dock_file)

  expect_identical(
    paste0(parsed$Dockerfile,  collapse = "\n"),
    paste0(readLines(dock_file), collapse = "\n")
  )

})
