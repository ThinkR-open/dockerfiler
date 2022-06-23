test_that("dockerfile is buildable", {

  # descdir <- tempfile(pattern = "desc")
  # dir.create(descdir)
  # file.copy("DESCRIPTION", descdir)
  my_dock <- dock_from_renv(lockfile = "renv.lock")
  cat(".RData
.Rhistory
.git
.gitignore
manifest.json
rsconnect/
.Rproj.user",file = ".dockerignore")
  # file.edit(".dockerignore")
  my_dock$write("Dockerfile")



  skip_on_cran()
  out_v <-system("docker -v")
skip_if_not(out_v == 0) #docker not available

  out_linux <-system("docker run rocker/r-base")

skip_if_not(out_linux == 2) # image operating system "linux" cannot be used on this platform

  out1 <-system("docker run hello-world ")
expect_equal(out1,0)

 out <- system("docker build . --file Dockerfile ",wait = TRUE)
# file.edit(tpf)
expect_equal(out,0)

unlink(".dockerignore")
})
