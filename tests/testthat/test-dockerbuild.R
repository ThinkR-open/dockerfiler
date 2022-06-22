

test_that("dockerfile is buildable", {

  descdir <- tempfile(pattern = "desc")
  dir.create(descdir)
  file.copy("DESCRIPTION", descdir)
  my_dock <- dockerfiler:::dock_from_desc(file.path(descdir, "DESCRIPTION"),
                                          FROM = "rocker/r-ver:4.1.2"


                                          )
  tpf <- "Dockerfile"
  dirname(tpf)
  cat(".RData
.Rhistory
.git
.gitignore
manifest.json
rsconnect/
.Rproj.user",file = ".dockerignore")
  # file.edit(".dockerignore")
  my_dock$write(tpf)
skip_on_cran()
  out1 <-system("docker run hello-world ")
expect_equal(out1,0)
 out <- system(sprintf("docker build . --file %s ",tpf),wait = TRUE)
# file.edit(tpf)
expect_equal(out,0)
})
