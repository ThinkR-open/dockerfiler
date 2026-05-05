test_that("docker_ignore_add creates a .dockerignore with the expected entries", {
  tmp <- tempfile(pattern = "ign")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

  out <- docker_ignore_add(path = tmp)
  di <- file.path(tmp, ".dockerignore")
  expect_true(file.exists(di))
  expect_identical(unname(out), unname(fs::path(tmp, ".dockerignore")))
  contents <- readLines(di)
  for (entry in c(".RData", ".Rhistory", ".git", ".gitignore",
                  "manifest.json", "rsconnect/", ".Rproj.user")) {
    expect_true(entry %in% contents, info = entry)
  }
})

test_that("docker_ignore_add appends to an existing .Rbuildignore", {
  tmp <- tempfile(pattern = "ign")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

  rbi <- file.path(tmp, ".Rbuildignore")
  writeLines("^pre-existing$", con = rbi)

  docker_ignore_add(path = tmp)

  rbi_lines <- readLines(rbi)
  expect_true("^pre-existing$" %in% rbi_lines)
  expect_true("^\\.dockerignore$" %in% rbi_lines)
})

test_that("docker_ignore_add is a no-op when .dockerignore already exists", {
  tmp <- tempfile(pattern = "ign")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

  di <- file.path(tmp, ".dockerignore")
  writeLines("preexisting-line", con = di)
  rbi <- file.path(tmp, ".Rbuildignore")
  writeLines("^preexisting$", con = rbi)

  docker_ignore_add(path = tmp)

  expect_identical(readLines(di), "preexisting-line")
  expect_identical(readLines(rbi), "^preexisting$")
})
