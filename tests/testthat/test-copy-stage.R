test_that("Dockerfile COPY with build stage works correctly", {
  # Création des deux étapes du Dockerfile
  stage_1 <- Dockerfile$new(FROM = "alpine", AS = "builder")
  stage_1$RUN('echo "coucou depuis le builder" > /coucou')

  stage_2 <- Dockerfile$new(FROM = "ubuntu")
  stage_2$COPY(from = "/coucou", to = "/truc.txt", force = TRUE, stage = "builder")
  stage_2$RUN("cat /truc.txt")

  tmpfile <- tempfile(fileext = ".Dockerfile")
  stage_1$write(as = tmpfile)
  stage_2$write(as = tmpfile, append = TRUE)

  docker_lines <- readLines(tmpfile)

  expect_length(docker_lines, 5)

  expect_equal(docker_lines[1], "FROM alpine AS builder")
  expect_equal(docker_lines[2], 'RUN echo "coucou depuis le builder" > /coucou')
  expect_equal(docker_lines[3], "FROM ubuntu")
  expect_equal(docker_lines[4], "COPY --from=builder /coucou /truc.txt")
  expect_equal(docker_lines[5], "RUN cat /truc.txt")

  expect_true(any(grepl("COPY --from=builder", docker_lines)))
  expect_true(any(grepl("/coucou", docker_lines)))
  expect_true(any(grepl("/truc.txt", docker_lines)))
})
