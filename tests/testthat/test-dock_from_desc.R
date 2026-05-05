base_pkg_ <- c(
  "base",
  "boot",
  "class",
  "cluster",
  "codetools",
  "compiler",
  "datasets",
  "foreign",
  "graphics",
  "grDevices",
  "grid",
  "KernSmooth",
  "lattice",
  "MASS",
  "Matrix",
  "methods",
  "mgcv",
  "nlme",
  "nnet",
  "parallel",
  "rpart",
  "spatial",
  "splines",
  "stats",
  "stats4",
  "survival",
  "tcltk",
  "tools",
  "utils"
)

descdir <- tempfile(pattern = "desc")
dir.create(descdir)
file.copy("DESCRIPTION__", descdir)
withr::with_dir(
  descdir,
  {
    test_that("dock_from_desc works", {

      skip_if(is_rdevel, "skip on R-devel")

      my_dock <- dock_from_desc(file.path(".", "DESCRIPTION__"))

      expect_s3_class(my_dock, "R6")
      expect_s3_class(my_dock, "Dockerfile")

      tpf <- tempfile()

      my_dock$write(tpf)

      tpf <- paste(
        readLines(tpf),
        collapse = " "
      )

      expect_true(
        grepl(
          "rocker/r-ver",
          tpf
        )
      )


      expect_true(
        grepl(
          "mkdir /build_zone",
          tpf
        )
      )
      expect_true(
        grepl(
          "rm -rf /build_zone",
          tpf
        )
      )

      x <- desc::desc_get_deps(file.path(".", "DESCRIPTION__"))
      x <- x[x$type == "Imports" & !(x$package %in% base_pkg_), ]
      if (length(x) > 0) {
        for (i in x$package) {
          expect_true(
            grepl(
              i,
              tpf
            )
          )
        }
      }

      # Only if package I guess
      # expect_true(file.exists(file.path(descdir, ".Rbuildignore")))
      expect_true(file.exists(file.path(descdir, ".dockerignore")))









      skip_if(is_rdevel, "Skippé sous R-devel")

      expect_true(
        grepl(
          "apt-get update && apt-get install",
          tpf
        )
      )

      unlink(tpf, recursive = TRUE)



    })

    test_that("dock_from_desc emits no GITHUB_PAT plumbing by default", {
      skip_if(is_rdevel, "skip on R-devel")
      my_dock <- dock_from_desc(file.path(".", "DESCRIPTION__"))
      df <- paste(my_dock$Dockerfile, collapse = "\n")
      expect_false(grepl("GITHUB_PAT", df))
      expect_false(grepl("--mount=type=secret", df, fixed = TRUE))
    })

    test_that("dock_from_desc emits ARG/ENV GITHUB_PAT when github_pat = 'build_arg'", {
      skip_if(is_rdevel, "skip on R-devel")
      my_dock <- dock_from_desc(
        file.path(".", "DESCRIPTION__"),
        github_pat = "build_arg"
      )
      df <- paste(my_dock$Dockerfile, collapse = "\n")
      expect_match(df, "ARG GITHUB_PAT", fixed = TRUE)
      expect_match(df, 'ENV "GITHUB_PAT"="${GITHUB_PAT}"', fixed = TRUE)
      # No secret mount fragment in build_arg mode.
      expect_false(grepl("--mount=type=secret", df, fixed = TRUE))
    })

    test_that("dock_from_desc emits secret mounts when github_pat = 'secret'", {
      skip_if(is_rdevel, "skip on R-devel")
      my_dock <- dock_from_desc(
        file.path(".", "DESCRIPTION__"),
        github_pat = "secret"
      )
      df <- paste(my_dock$Dockerfile, collapse = "\n")
      # No top-level ARG / ENV in secret mode.
      expect_false(grepl("ARG GITHUB_PAT", df, fixed = TRUE))
      expect_false(grepl('ENV "GITHUB_PAT"', df, fixed = TRUE))
      # The install_local RUN must carry the secret-mount fragment plus
      # a `cat /run/secrets/...` shell prefix that exposes the PAT as
      # an env var to the inner R command (compatible with all BuildKit
      # versions, unlike the `env=GITHUB_PAT` shortcut on the mount).
      expect_match(
        df,
        "--mount=type=secret,id=github_pat GITHUB_PAT=$(cat /run/secrets/github_pat)",
        fixed = TRUE
      )
    })

    test_that("dock_from_desc(build_from_source = FALSE) copies a prebuilt tar.gz", {
      skip_if(is_rdevel, "skip on R-devel")
      fake_tar <- "fakepkg_0.0.0.tar.gz"
      file.create(fake_tar)
      on.exit(unlink(fake_tar), add = TRUE)
      my_dock <- testthat::with_mocked_bindings(
        code = dock_from_desc(
          file.path(".", "DESCRIPTION__"),
          build_from_source = FALSE,
          update_tar_gz = FALSE
        ),
        get_sysreqs = function(...) character(0)
      )
      df <- paste(my_dock$Dockerfile, collapse = "\n")
      expect_match(df, "tar.gz", fixed = TRUE)
      expect_match(df, "remotes::install_local", fixed = TRUE)
      expect_match(df, "rm /app.tar.gz", fixed = TRUE)
      expect_false(grepl("mkdir /build_zone", df, fixed = TRUE))
    })
  }
)

unlink(descdir, recursive = TRUE)
