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
      # pak::pkg_sysreqs(sysreqs_platform = "ubuntu") returns no
      # system_packages on macOS hosts, so the apt-get install line is
      # never emitted and the assertion below cannot pass. Tests
      # exercising the same path are skipped together.
      skip_on_os("mac")

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

    test_that("dock_from_desc(build_from_source = FALSE, update_tar_gz = FALSE) copies a prebuilt tar.gz", {
      skip_if(is_rdevel, "skip on R-devel")
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

    test_that("dock_from_desc(build_from_source = FALSE, update_tar_gz = TRUE) builds a fresh tar.gz", {
      skip_if(is_rdevel, "skip on R-devel")
      build_called <- FALSE
      use_build_ignore_called <- FALSE
      my_dock <- testthat::with_mocked_bindings(
        code = dock_from_desc(
          file.path(".", "DESCRIPTION__"),
          build_from_source = FALSE,
          update_tar_gz = TRUE
        ),
        get_sysreqs = function(...) character(0),
        build = function(path, dest_path, vignettes) {
          build_called <<- TRUE
          fake <- file.path(dest_path, "fakepkg_0.0.0.tar.gz")
          file.create(fake)
          fake
        },
        use_build_ignore = function(files) {
          use_build_ignore_called <<- TRUE
          invisible(TRUE)
        }
      )
      # Both surviving lines from the dead-code-removal must execute on
      # this code path.
      expect_true(build_called)
      expect_true(use_build_ignore_called)
      df <- paste(my_dock$Dockerfile, collapse = "\n")
      expect_match(df, "remotes::install_local", fixed = TRUE)
    })


    test_that("dock_from_desc messages the user when DESCRIPTION declares SystemRequirements", {
      skip_if(is_rdevel, "skip on R-devel")
      # Write a DESCRIPTION with a SystemRequirements field next to the
      # existing fixture so we exercise the `else if (!is.na(sr))`
      # message branch (only fires when extra_sysreqs is NULL).
      lines <- readLines("DESCRIPTION__")
      lines <- c(lines, "SystemRequirements: imagemagick, libcurl")
      desc_with_sr <- "DESCRIPTION_with_sr"
      writeLines(lines, con = desc_with_sr)
      on.exit(unlink(desc_with_sr), add = TRUE)

      expect_message(
        dock_from_desc(
          path = file.path(".", desc_with_sr),
          sysreqs = FALSE
        ),
        "imagemagick, libcurl"
      )
    })

    test_that("dock_from_desc with sysreqs = FALSE emits no apt-get install", {
      skip_if(is_rdevel, "skip on R-devel")
      my_dock <- dock_from_desc(
        file.path(".", "DESCRIPTION__"),
        sysreqs = FALSE
      )
      df <- paste(my_dock$Dockerfile, collapse = "\n")
      expect_false(grepl("apt-get install", df))
      expect_false(grepl("apt-get update", df))
    })

    test_that("dock_from_desc(extra_sysreqs = ...) emits an apt-get install for the extras", {
      skip_if(is_rdevel, "skip on R-devel")
      my_dock <- dock_from_desc(
        file.path(".", "DESCRIPTION__"),
        sysreqs = FALSE,
        extra_sysreqs = c("libsodium-dev", "libxml2-dev")
      )
      df <- paste(my_dock$Dockerfile, collapse = "\n")
      expect_match(df, "apt-get install -y[^\n]*libsodium-dev")
      expect_match(df, "apt-get install -y[^\n]*libxml2-dev")
    })

    test_that("dock_from_desc(expand = TRUE) emits one apt-get install RUN per requirement plus update / clean", {
      skip_if(is_rdevel, "skip on R-devel")
      my_dock <- dock_from_desc(
        file.path(".", "DESCRIPTION__"),
        sysreqs = FALSE,
        expand = TRUE,
        extra_sysreqs = c("libsodium-dev", "libxml2-dev")
      )
      df <- my_dock$Dockerfile
      expect_true(any(df == "RUN apt-get update"))
      expect_true(any(grepl("RUN apt-get install -y +libsodium-dev$", df)))
      expect_true(any(grepl("RUN apt-get install -y +libxml2-dev$", df)))
      expect_true(any(df == "RUN rm -rf /var/lib/apt/lists/*"))
    })

    test_that("dock_from_desc(build_from_source = FALSE, update_tar_gz = TRUE) builds the tar.gz and removes any pre-existing one", {
      skip_if(is_rdevel, "skip on R-devel")
      # Pre-existing tarball that should be removed before the rebuild.
      pkg_name <- "dockerfiler"
      old_tar <- sprintf("%s_0.0.0.tar.gz", pkg_name)
      writeLines("preexisting", con = old_tar)
      on.exit(unlink(old_tar), add = TRUE)

      fake_built <- sprintf("%s_9.9.9.tar.gz", pkg_name)

      # Avoid actually invoking pkgbuild + usethis; both are slow /
      # disk-touching and not what this test exercises (we want the
      # build branch to *run*, not to actually build). The bindings
      # are resolved through dockerfiler's own namespace because of
      # the `@importFrom pkgbuild build` and `@importFrom usethis
      # use_build_ignore`, so we mock against `.package = "dockerfiler"`.
      testthat::with_mocked_bindings(
        code = {
          expect_output(
            my_dock <- dock_from_desc(
              path = file.path(".", "DESCRIPTION__"),
              sysreqs = FALSE,
              build_from_source = FALSE,
              update_tar_gz = TRUE
            ),
            "removed from folder"
          )
          df <- paste(my_dock$Dockerfile, collapse = "\n")
          # The prebuilt-tarball plumbing must still be emitted, same
          # as the update_tar_gz = FALSE path.
          expect_match(df, "COPY dockerfiler_\\*.tar.gz /app.tar.gz")
          expect_match(
            df,
            "remotes::install_local\\(\"/app.tar.gz\",upgrade=\"never\"\\)"
          )
        },
        build = function(path, dest_path, vignettes) fake_built,
        use_build_ignore = function(files) invisible(files),
        .package = "dockerfiler"
      )

      # The pre-existing tarball must have been removed by the cleanup step.
      expect_false(file.exists(old_tar))
    })

    test_that("dock_from_desc(build_from_source = FALSE, update_tar_gz = FALSE) emits a COPY + install_local of the prebuilt tarball", {
      skip_if(is_rdevel, "skip on R-devel")
      my_dock <- dock_from_desc(
        file.path(".", "DESCRIPTION__"),
        sysreqs = FALSE,
        build_from_source = FALSE,
        update_tar_gz = FALSE
      )
      df <- paste(my_dock$Dockerfile, collapse = "\n")
      # The non-tar.gz-rebuilding path must:
      # 1. NOT use the source-mount path (mkdir /build_zone, ADD ., WORKDIR).
      expect_false(grepl("mkdir /build_zone", df, fixed = TRUE))
      expect_false(grepl("WORKDIR /build_zone", df, fixed = TRUE))
      # 2. COPY the tar.gz glob and call remotes::install_local on it.
      expect_match(df, "COPY dockerfiler_\\*.tar.gz /app.tar.gz")
      expect_match(
        df,
        "remotes::install_local\\(\"/app.tar.gz\",upgrade=\"never\"\\)"
      )
      # 3. Clean up the tarball after install.
      expect_match(df, "rm /app.tar.gz")
    })

    test_that("dock_from_desc emits remotes::install_github for non-CRAN deps", {
      skip_if(is_rdevel, "skip on R-devel")
      # The `Remotes:` (GitHub) install branch iterates over
      # `remotes_deps$remote` filtered by `!is_cran`. We synthesise a
      # mock `remotes::package_deps()` return with one CRAN row and
      # one GitHub row whose `$remote` carries
      # `(repo, username, sha)` so the test exercises the
      # `install_github` emission path without hitting the network or
      # requiring a non-CRAN package to be installed.
      fake_pd <- data.frame(
        package = c("cli", "fakepkg"),
        is_cran = c(TRUE, FALSE),
        installed = c("3.6.1", NA),
        stringsAsFactors = FALSE
      )
      fake_pd$remote <- list(
        list(),
        list(repo = "fakepkg", username = "ghuser", sha = "deadbeef")
      )
      testthat::with_mocked_bindings(
        code = {
          my_dock <- dock_from_desc(
            file.path(".", "DESCRIPTION__"),
            sysreqs = FALSE
          )
          df <- paste(my_dock$Dockerfile, collapse = "\n")
          expect_match(
            df,
            'remotes::install_github("ghuser/fakepkg@deadbeef")',
            fixed = TRUE
          )
        },
        package_deps = function(packages) fake_pd,
        .package = "remotes"
      )
    })

    test_that("dock_from_desc(github_pat = 'secret') decorates install_github with a secret mount", {
      skip_if(is_rdevel, "skip on R-devel")
      fake_pd <- data.frame(
        package = c("cli", "fakepkg"),
        is_cran = c(TRUE, FALSE),
        installed = c("3.6.1", NA),
        stringsAsFactors = FALSE
      )
      fake_pd$remote <- list(
        list(),
        list(repo = "fakepkg", username = "ghuser", sha = "deadbeef")
      )
      testthat::with_mocked_bindings(
        code = {
          my_dock <- dock_from_desc(
            file.path(".", "DESCRIPTION__"),
            sysreqs = FALSE,
            github_pat = "secret"
          )
          df <- paste(my_dock$Dockerfile, collapse = "\n")
          # The install_github RUN must carry the secret-mount fragment
          # ahead of the Rscript invocation on the same line.
          expect_match(
            df,
            "--mount=type=secret,id=github_pat GITHUB_PAT=\\$\\(cat /run/secrets/github_pat\\)[^\n]*remotes::install_github"
          )
        },
        package_deps = function(packages) fake_pd,
        .package = "remotes"
      )
    })
  }
)

unlink(descdir, recursive = TRUE)
