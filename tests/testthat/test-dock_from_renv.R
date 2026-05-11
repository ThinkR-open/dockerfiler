
# A temporary directory
dir_build <- tempfile(pattern = "renv")
dir.create(dir_build)

# Create a lockfile
the_lockfile <- file.path(dir_build, "renv.lock")

custom_packages <- c(
  # attachment::att_from_description(),
  "cli",
  "glue", # "golem",
  "shiny",
  "stats",
  "utils",
  "testthat",
  "knitr"
)
if (!testthat:::on_cran() && requireNamespace("renv", quietly = TRUE)) {
  renv::snapshot(
    packages = custom_packages,
    lockfile = the_lockfile,
    prompt = FALSE
  )
} else {
  file.copy(from = system.file("renv.lock", package = "dockerfiler"), to = the_lockfile)
}

# Modify R version for tests
renv_file <- readLines(file.path(dir_build, "renv.lock"))
renv_file[grep("Version", renv_file)[1]] <- '    "Version": "4.1.2",'
writeLines(renv_file, file.path(dir_build, "renv.lock"))



# dock_from_renv ----
test_that("dock_from_renv works", {

  # testthat::skip_on_cran()
  # skip_if_not(interactive())
  # Create Dockerfile
  skip_if(is_rdevel, "skip on R-devel")

  testthat::with_mocked_bindings(code = {
    out <- dock_from_renv(
      lockfile = the_lockfile,
      FROM = "rocker/verse",
      # Use a non-PPM repos so this fixture-comparison test keeps
      # locking the basic Dockerfile shape; the PPM rewrite has its
      # own dedicated tests.
      repos = c(CRAN = "https://cran.rstudio.com/"),
      renv_version = "0.0.0"
    )
  },
  compact_sysreqs = function(...) "fake sys reqs",
  repos_as_character = function(...) "fake repos"
  )

  expect_s3_class(
    out,
    "Dockerfile"
  )
  expect_s3_class(
    out,
    "R6"
  )

  # read Dockerfile
  out$write(
    file.path(
      dir_build,
      "Dockerfile"
    )
  )

  dock_created <- readLines(
    file.path(
      dir_build,
      "Dockerfile"
    )
  )

  dock_expected <- readLines(
    testthat::test_path("renv_Dockerfile")
  )

  expect_equal(dock_created, dock_expected)

  skip_if(is_rdevel, "Skip R-devel")
  #python3 is not a direct dependencies from custom_packages
  expect_false(  any(grepl("python3",out$Dockerfile)))

})
# rstudioapi::navigateToFile(file.path(dir_build, "Dockerfile"))
#
test_that("dock_from_renv works with full dependencies", {
  # testthat::skip_on_cran()
  # skip_if_not(interactive())
  # Create Dockerfile
skip_if(is_rdevel, "skip on R-devel")
  # pak::pkg_sysreqs(sysreqs_platform = "ubuntu") returns no
  # system_packages on macOS hosts, so the python3 sysreq line is
  # never emitted and the assertion below cannot pass.
  skip_on_os("mac")
  out <- dock_from_renv(
    dependencies = TRUE,
    lockfile = the_lockfile,
    FROM = "rocker/verse",
  )
  expect_s3_class(
    out,
    "Dockerfile"
  )
  expect_s3_class(
    out,
    "R6"
  )
  skip_if(is_rdevel, "Skip R-devel")
  #python3 is  a un-direct dependencies from custom_packages
  expect_true(  any(grepl("python3",out$Dockerfile)))
})
# rstudioapi::navigateToFile(file.path(dir_build, "Dockerfile"))



# repos_as_character ----
test_that("repos_as_character works", {
  out <- dockerfiler:::repos_as_character(
    repos = c(
      RSPM = paste0("https://packagemanager.rstudio.com/all/__linux__/focal/latest"),
      CRAN = "https://cran.rstudio.com/"
    )
  )
  expect_equal(
    out,
    "c(RSPM = 'https://packagemanager.rstudio.com/all/__linux__/focal/latest', CRAN = 'https://cran.rstudio.com/')"
  )
})

# gen_base_image ----
test_that("gen_base_image works", {
  out <- dockerfiler:::gen_base_image(
    r_version = "4.0",
    FROM = "rstudio/r-base"
  )
  expect_equal(out, "rstudio/r-base:4.0")

  out <- dockerfiler:::gen_base_image(
    r_version = "4.0",
    FROM = "rocker/verse"
  )
  expect_equal(out, "rocker/verse:4.0")
})

test_that("dock_from_renv default FROM is rocker/r-ver, default repos is p3m.dev/cran/latest", {
  fmls <- formals(dock_from_renv)
  expect_equal(fmls$FROM, "rocker/r-ver")
  # `formals()` returns the unevaluated default; capture as string.
  expect_equal(
    deparse(fmls$repos),
    'c(CRAN = "https://p3m.dev/cran/latest")'
  )
})

test_that("dock_from_renv defaults produce a multi-arch FROM auto-tagged from the lockfile R version", {
  skip_if(is_rdevel, "skip on R-devel")
  out <- dock_from_renv(
    lockfile = the_lockfile,
    user = NULL,
    renv_version = "0.0.0"
  )
  # Default FROM = rocker/r-ver is untagged; gen_base_image appends
  # the lockfile's R version (4.1.2 in the test setup).
  expect_true("FROM rocker/r-ver:4.1.2" %in% out$Dockerfile)
})

test_that("dock_from_renv defaults trigger the PPM rewrite (codename + UA + override)", {
  skip_if(is_rdevel, "skip on R-devel")
  out <- dock_from_renv(
    lockfile = the_lockfile,
    user = NULL,
    renv_version = "0.0.0"
  )
  df <- paste(out$Dockerfile, collapse = "\n")
  # The default p3m.dev URL must be rewritten to the
  # `__linux__/$VERSION_CODENAME/` shape so the build pulls Linux
  # binaries.
  expect_match(df, "https://p3m\\.dev/cran/__linux__/\\$VERSION_CODENAME/latest")
  # The HTTPUserAgent line must be emitted (PPM serves source if it
  # is missing even with a `__linux__/` URL).
  expect_match(df, "HTTPUserAgent = sprintf\\('R \\(")
  # The renv config repos override must point at the rewritten URL.
  expect_match(df, "renv\\.config\\.repos\\.override = c\\(CRAN = '")
  # The /etc/os-release source must be prefixed on the RUN that uses
  # $VERSION_CODENAME.
  expect_match(df, "\\. /etc/os-release && ")
})

test_that(".patch_rprofile_for_ppm rejects PPM host typos that the (posit|rstudio).(co|com) Cartesian product would have admitted", {
  # `posit.com` and `rstudio.co` are typos -- not real Posit-managed
  # hosts. Without the explicit enumeration, an alternation
  # `(posit|rstudio).(co|com)` matches both and rewrites the URL to a
  # codename form against a host that does not resolve. Lock the
  # explicit host whitelist by exercising both typos.
  skip_if(is_rdevel, "skip on R-devel")
  for (typo_url in c(
    "https://packagemanager.posit.com/cran/latest",
    "https://packagemanager.rstudio.co/cran/latest"
  )) {
    out <- dock_from_renv(
      lockfile = the_lockfile,
      user = NULL,
      repos = setNames(typo_url, "CRAN"),
      renv_version = "0.0.0"
    )
    df <- paste(out$Dockerfile, collapse = "\n")
    expect_false(
      grepl("__linux__", df, fixed = TRUE),
      info = sprintf(
        "PPM rewrite incorrectly fired on typo host %s",
        typo_url
      )
    )
  }
})

test_that(".validate_r_version accepts R-devel, release-candidate and Patched lockfile shapes", {
  # renv records these forms in real lockfiles. The post-#109
  # validator originally rejected them, blocking the user from
  # `dock_from_renv()` whenever the new `FROM = "rocker/r-ver"`
  # default routed through the auto-tag path.
  expect_silent(dockerfiler:::.validate_r_version("4.5"))
  expect_silent(dockerfiler:::.validate_r_version("4.5.0"))
  expect_silent(dockerfiler:::.validate_r_version("4.5.0-RC"))
  expect_silent(dockerfiler:::.validate_r_version("r-devel"))
  expect_silent(dockerfiler:::.validate_r_version("3.6.0 Patched"))
  # Still reject obvious garbage / shell metacharacters.
  expect_error(
    dockerfiler:::.validate_r_version("4.5; rm -rf /"),
    "r_version"
  )
  expect_error(
    dockerfiler:::.validate_r_version(""),
    "r_version"
  )
  # The "<X.Y.Z> Patched" branch matches a single literal space only:
  # a newline or tab between the version and "Patched" would otherwise
  # slip through (R's `\\s` matches `\n` / `\t`) and produce a
  # two-line FROM directive in the generated Dockerfile.
  expect_error(
    dockerfiler:::.validate_r_version("4.5.0\nPatched"),
    "r_version"
  )
  expect_error(
    dockerfiler:::.validate_r_version("4.5.0\tPatched"),
    "r_version"
  )
})

test_that(".patch_rprofile_for_ppm matches all three current PPM host shapes", {
  for (host in c(
    "packagemanager.rstudio.com",
    "packagemanager.posit.co",
    "p3m.dev"
  )) {
    skip_if(is_rdevel, "skip on R-devel")
    out <- dock_from_renv(
      lockfile = the_lockfile,
      user = NULL,
      repos = setNames(
        sprintf("https://%s/cran/latest", host),
        "CRAN"
      ),
      renv_version = "0.0.0"
    )
    df <- paste(out$Dockerfile, collapse = "\n")
    expect_match(
      df,
      sprintf("https://%s/cran/__linux__/\\$VERSION_CODENAME/latest", host),
      info = sprintf("PPM rewrite did not fire on host %s", host)
    )
  }
})

test_that("gen_base_image preserves an already-pinned tag instead of appending r_version", {
  # Without the guard, `gen_base_image(FROM = "rocker/r-base:4.5", r_version = "4.1.2")`
  # returned "rocker/r-base:4.5:4.1.2" -- an invalid image reference.
  expect_equal(
    dockerfiler:::gen_base_image(
      r_version = "4.1.2",
      FROM = "rocker/r-base:4.5"
    ),
    "rocker/r-base:4.5"
  )
  # Same protection for sha256 digests.
  expect_equal(
    dockerfiler:::gen_base_image(
      r_version = "4.1.2",
      FROM = "rocker/r-base@sha256:abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789"
    ),
    "rocker/r-base@sha256:abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789"
  )
  # Untagged FROM still gets the r_version appended.
  expect_equal(
    dockerfiler:::gen_base_image(
      r_version = "4.1.2",
      FROM = "rocker/r-base"
    ),
    "rocker/r-base:4.1.2"
  )
})

test_that("gen_base_image warns when the deprecated `distro` is supplied", {
  expect_warning(
    out <- dockerfiler:::gen_base_image(
      distro = "xenial",
      r_version = "4.0",
      FROM = "rocker/verse"
    ),
    "distro"
  )
  # Even though the deprecation fires, the resulting image string still
  # comes from FROM + r_version (distro is dead).
  expect_equal(out, "rocker/verse:4.0")
})





test_that("dock_from_renv works with specific renv", {

  skip_if(is_rdevel, "skip on R-devel")
  # testthat::skip_on_cran()
the_lockfile1.0.0 <- system.file("renv_with_1.0.0.lock",package = "dockerfiler")

for (lf in list(the_lockfile,the_lockfile1.0.0)){
for (renv_version in list(NULL,"1.2.3","missing")){


  if (!is.null(renv_version) && renv_version == "missing") {
    out <- dock_from_renv(lockfile = lf,
                          FROM = "rocker/verse")
  } else{
    out <- dock_from_renv(
      lockfile = lf,
      FROM = "rocker/verse",
      renv_version = renv_version
    )

  }
socle_install_version <- "remotes::install_version\\(\"renv\", version = \""
  if (lf == the_lockfile &    is.null(renv_version)) {
    test_string <- 'install.packages\\(\"renv\"\\)'
  } else if (lf == the_lockfile1.0.0 & is.null(renv_version)) {
    test_string <- 'install.packages\\(\"renv\"\\)'
  } else if (lf == the_lockfile &  renv_version == "1.2.3") {
    test_string <-  paste0(socle_install_version,"1.2.3"  ,"\"\\)")
  } else if (lf == the_lockfile1.0.0 & renv_version == "1.2.3") {
    test_string <- paste0(socle_install_version,"1.2.3","\"\\)")
  } else if (lf == the_lockfile & renv_version == "missing") {
    # When the lockfile does not pin renv, we install the latest from
    # the configured repos (same behaviour as renv_version = NULL).
    test_string <- 'install.packages\\(\"renv\"\\)'
  } else if (lf == the_lockfile1.0.0 & renv_version == "missing") {
    test_string <-paste0(socle_install_version,"1.0.0","\"\\)")
  }

  expect_true( any(   grepl(test_string , out$Dockerfile)    ),
               info = paste(lf," & ",renv_version))

  installs_latest <- is.null(renv_version) ||
    (identical(renv_version, "missing") && lf == the_lockfile)
  if (installs_latest) {
    # When using the latest renv, `remotes` must not be installed at
    # all. Tighter regex than `grepl("remotes", ...)` so we don't
    # false-positive on incidental occurrences of the substring (e.g.
    # a host name) elsewhere in the Dockerfile.
    expect_false(
      any(grepl("install\\.packages\\([^)]*remotes", out$Dockerfile)),
      info = paste(lf, " & ", renv_version, " => no remotes install")
    )
    expect_false(
      any(grepl("remotes::install_version", out$Dockerfile)),
      info = paste(lf, " & ", renv_version, " => no remotes::install_version")
    )
  }

}}




})

test_that("dock_from_renv injects PPM HTTPUserAgent, codename and renv override when repos is PPM", {
  skip_if(is_rdevel, "skip on R-devel")
  out <- dock_from_renv(
    lockfile = the_lockfile,
    FROM = "rocker/verse",
    repos = c(CRAN = "https://packagemanager.posit.co/cran/latest"),
    renv_version = "0.0.0"
  )
  df <- paste(out$Dockerfile, collapse = "\n")
  expect_match(df, "__linux__/\\$VERSION_CODENAME/")
  expect_match(df, "HTTPUserAgent = sprintf\\('R \\(")
  expect_match(df, "\\. /etc/os-release && ")
  expect_match(df, "renv\\.config\\.repos\\.override = c\\(CRAN = '")
  # Lock the UA escape level: the Dockerfile must contain literal
  # `R.Version()\$platform` so bash's `echo "..."` emits a `$` (which R
  # then evaluates correctly in Rprofile.site).
  expect_match(df, "R.Version()\\$platform", fixed = TRUE)
  expect_match(df, "R.Version()\\$arch", fixed = TRUE)
  expect_match(df, "R.Version()\\$os", fixed = TRUE)
})

test_that("dock_from_renv leaves non-PPM repos untouched", {
  skip_if(is_rdevel, "skip on R-devel")
  out <- dock_from_renv(
    lockfile = the_lockfile,
    FROM = "rocker/verse",
    repos = c(CRAN = "https://cran.rstudio.com/"),
    renv_version = "0.0.0"
  )
  df <- paste(out$Dockerfile, collapse = "\n")
  expect_false(any(grepl("__linux__", out$Dockerfile)))
  expect_false(any(grepl("HTTPUserAgent", out$Dockerfile)))
  expect_false(any(grepl("/etc/os-release", out$Dockerfile)))
  expect_false(any(grepl("renv\\.config\\.repos\\.override", out$Dockerfile)))
})

test_that("dock_from_renv preserves user-pinned PPM codename", {
  skip_if(is_rdevel, "skip on R-devel")
  out <- dock_from_renv(
    lockfile = the_lockfile,
    FROM = "rocker/verse",
    repos = c(CRAN = "https://packagemanager.posit.co/cran/__linux__/jammy/latest"),
    renv_version = "0.0.0"
  )
  df <- paste(out$Dockerfile, collapse = "\n")
  expect_match(df, "__linux__/jammy/", fixed = TRUE)
  expect_false(any(grepl("\\$VERSION_CODENAME", out$Dockerfile)))
  expect_match(df, "HTTPUserAgent = sprintf")
  # The override must reference the user-pinned URL, not the codename URL.
  expect_match(
    df,
    "renv.config.repos.override = c(CRAN = 'https://packagemanager.posit.co/cran/__linux__/jammy/latest')",
    fixed = TRUE
  )
})

test_that("dock_from_renv preserves a PPM snapshot-date URL", {
  skip_if(is_rdevel, "skip on R-devel")
  snapshot_url <- "https://packagemanager.posit.co/cran/2024-01-15"
  out <- dock_from_renv(
    lockfile = the_lockfile,
    FROM = "rocker/verse",
    repos = c(CRAN = snapshot_url),
    renv_version = "0.0.0"
  )
  df <- paste(out$Dockerfile, collapse = "\n")
  # The snapshot date must survive (no clobbering to /latest).
  expect_match(df, "cran/2024-01-15", fixed = TRUE)
  expect_false(any(grepl("\\$VERSION_CODENAME", out$Dockerfile)))
  expect_false(any(grepl("/etc/os-release", out$Dockerfile)))
  # The override must reference the user URL, not the codename URL.
  expect_match(
    df,
    sprintf(
      "renv.config.repos.override = c(CRAN = '%s')",
      snapshot_url
    ),
    fixed = TRUE
  )
  # User-Agent is still useful with PPM regardless of URL form.
  expect_match(df, "HTTPUserAgent = sprintf")
})

test_that("dock_from_renv leaves multi-entry repos vectors untouched", {
  skip_if(is_rdevel, "skip on R-devel")
  # The PPM patch is intentionally limited to a single CRAN-keyed PPM URL;
  # multi-entry vectors fall through unmodified (back-compat / no surprises).
  out <- dock_from_renv(
    lockfile = the_lockfile,
    FROM = "rocker/verse",
    repos = c(
      RSPM = "https://packagemanager.posit.co/cran/latest",
      CRAN = "https://cran.rstudio.com/"
    ),
    renv_version = "0.0.0"
  )
  expect_false(any(grepl("__linux__", out$Dockerfile)))
  expect_false(any(grepl("HTTPUserAgent", out$Dockerfile)))
  expect_false(any(grepl("/etc/os-release", out$Dockerfile)))
  expect_false(any(grepl("renv\\.config\\.repos\\.override", out$Dockerfile)))
})

test_that(".patch_rprofile_for_ppm is idempotent", {
  skip_if(is_rdevel, "skip on R-devel")
  out <- dock_from_renv(
    lockfile = the_lockfile,
    FROM = "rocker/verse",
    repos = c(CRAN = "https://packagemanager.posit.co/cran/latest"),
    renv_version = "0.0.0"
  )
  before <- out$Dockerfile
  # Re-applying the helper must be a no-op: each mutation is gated by
  # the absence of its target token.
  dockerfiler:::.patch_rprofile_for_ppm(
    out,
    repos = c(CRAN = "https://packagemanager.posit.co/cran/latest")
  )
  expect_identical(out$Dockerfile, before)
})

test_that("dock_from_renv handles a trailing slash on cran/latest/", {
  skip_if(is_rdevel, "skip on R-devel")
  out <- dock_from_renv(
    lockfile = the_lockfile,
    FROM = "rocker/verse",
    repos = c(CRAN = "https://packagemanager.posit.co/cran/latest/"),
    renv_version = "0.0.0"
  )
  df <- paste(out$Dockerfile, collapse = "\n")
  # Trailing slash must not block the codename rewrite.
  expect_match(df, "__linux__/\\$VERSION_CODENAME/")
  expect_match(df, "HTTPUserAgent = sprintf")
})

test_that("dock_from_renv preserves the user's PPM host on rewrite", {
  skip_if(is_rdevel, "skip on R-devel")
  # rstudio.com (the legacy alias) must not be silently rewritten to
  # posit.co; the user's scheme + host is preserved.
  out <- dock_from_renv(
    lockfile = the_lockfile,
    FROM = "rocker/verse",
    repos = c(CRAN = "https://packagemanager.rstudio.com/cran/latest"),
    renv_version = "0.0.0"
  )
  df <- paste(out$Dockerfile, collapse = "\n")
  expect_match(
    df,
    "packagemanager.rstudio.com/cran/__linux__/$VERSION_CODENAME/latest",
    fixed = TRUE
  )
  expect_false(grepl("packagemanager.posit.co", df, fixed = TRUE))
})

test_that("dock_from_renv emits no GITHUB_PAT plumbing by default", {
  skip_if(is_rdevel, "skip on R-devel")
  out <- dock_from_renv(
    lockfile = the_lockfile,
    FROM = "rocker/verse",
    renv_version = "0.0.0"
  )
  df <- paste(out$Dockerfile, collapse = "\n")
  expect_false(grepl("GITHUB_PAT", df))
  expect_false(grepl("--mount=type=secret", df, fixed = TRUE))
})

test_that("dock_from_renv emits ARG/ENV GITHUB_PAT when github_pat = 'build_arg'", {
  skip_if(is_rdevel, "skip on R-devel")
  out <- dock_from_renv(
    lockfile = the_lockfile,
    FROM = "rocker/verse",
    renv_version = "0.0.0",
    github_pat = "build_arg"
  )
  df <- paste(out$Dockerfile, collapse = "\n")
  expect_match(df, "ARG GITHUB_PAT", fixed = TRUE)
  expect_match(df, 'ENV "GITHUB_PAT"="${GITHUB_PAT}"', fixed = TRUE)
  expect_false(grepl("--mount=type=secret", df, fixed = TRUE))
})

test_that("dock_from_renv emits a secret mount on restore() when github_pat = 'secret'", {
  skip_if(is_rdevel, "skip on R-devel")
  out <- dock_from_renv(
    lockfile = the_lockfile,
    FROM = "rocker/verse",
    renv_version = "0.0.0",
    github_pat = "secret"
  )
  df <- paste(out$Dockerfile, collapse = "\n")
  expect_false(grepl("ARG GITHUB_PAT", df, fixed = TRUE))
  expect_false(grepl('ENV "GITHUB_PAT"', df, fixed = TRUE))
  expect_match(
    df,
    "--mount=type=secret,id=github_pat GITHUB_PAT=$(cat /run/secrets/github_pat)",
    fixed = TRUE
  )
  # The renv cache mount must coexist with the secret mount on the same RUN.
  # Cache target uses ${RENV_PATHS_CACHE} since renv_paths_cache landed.
  expect_match(
    df,
    "--mount=type=cache,id=renv-cache,target=${RENV_PATHS_CACHE} --mount=type=secret,id=github_pat GITHUB_PAT=$(cat /run/secrets/github_pat) R -e 'renv::restore()'",
    fixed = TRUE
  )
})

test_that("dock_from_renv emits the RENV_PATHS_CACHE build-arg by default", {
  skip_if(is_rdevel, "skip on R-devel")
  # Default user is "rstudio", so the default cache is auto-derived
  # to /home/rstudio. The build-arg, env and cache-mount tokens are
  # locked here regardless of which user the auto-derive picks.
  out <- dock_from_renv(
    lockfile = the_lockfile,
    FROM = "rocker/verse",
    renv_version = "0.0.0"
  )
  df <- paste(out$Dockerfile, collapse = "\n")
  expect_match(df, "ARG RENV_PATHS_CACHE=/home/rstudio/.cache/R/renv", fixed = TRUE)
  expect_match(df, 'ENV "RENV_PATHS_CACHE"="${RENV_PATHS_CACHE}"', fixed = TRUE)
  expect_match(
    df,
    "--mount=type=cache,id=renv-cache,target=${RENV_PATHS_CACHE}",
    fixed = TRUE
  )
})

test_that("dock_from_renv honors a custom renv_paths_cache path", {
  skip_if(is_rdevel, "skip on R-devel")
  out <- dock_from_renv(
    lockfile = the_lockfile,
    FROM = "rocker/verse",
    renv_paths_cache = "/srv/renv-cache",
    renv_version = "0.0.0"
  )
  df <- paste(out$Dockerfile, collapse = "\n")
  # Only the build-arg default changes -- the ENV value and the mount
  # target keep referencing the variable, so users overriding the path
  # at `docker build --build-arg RENV_PATHS_CACHE=...` still take effect
  # even if they don't change the dockerfile generation defaults.
  expect_match(df, "ARG RENV_PATHS_CACHE=/srv/renv-cache", fixed = TRUE)
  expect_match(df, 'ENV "RENV_PATHS_CACHE"="${RENV_PATHS_CACHE}"', fixed = TRUE)
  expect_match(
    df,
    "--mount=type=cache,id=renv-cache,target=${RENV_PATHS_CACHE}",
    fixed = TRUE
  )
  # The hard-coded /root/.cache/R/renv path must NOT remain in the file.
  expect_false(grepl("target=/root/.cache/R/renv", df, fixed = TRUE))
})

test_that("dock_from_renv emits a USER directive when `user` is non-NULL", {
  skip_if(is_rdevel, "skip on R-devel")
  out <- dock_from_renv(
    lockfile = the_lockfile,
    FROM = "rocker/verse",
    renv_version = "0.0.0",
    user = "rstudio"
  )
  expect_true(any(out$Dockerfile == "USER rstudio"))
})

test_that("dock_from_renv with sysreqs = FALSE skips sysreq computation and emits no apt-get install", {
  skip_if(is_rdevel, "skip on R-devel")
  out <- dock_from_renv(
    lockfile = the_lockfile,
    FROM = "rocker/verse",
    renv_version = "0.0.0",
    sysreqs = FALSE
  )
  df <- out$Dockerfile
  expect_false(any(grepl("apt-get install", df)))
  expect_false(any(grepl("apt-get update", df)))
})

test_that("dock_from_renv with sysreqs = FALSE + extra_sysreqs emits an apt-get install for the extras", {
  skip_if(is_rdevel, "skip on R-devel")
  out <- dock_from_renv(
    lockfile = the_lockfile,
    FROM = "rocker/verse",
    renv_version = "0.0.0",
    sysreqs = FALSE,
    extra_sysreqs = c("libsodium-dev", "libxml2-dev")
  )
  df <- paste(out$Dockerfile, collapse = "\n")
  # The two extras must end up in a compact apt-get install RUN.
  expect_match(df, "apt-get install -y[^\n]*libsodium-dev")
  expect_match(df, "apt-get install -y[^\n]*libxml2-dev")
})

test_that("dock_from_renv with expand = TRUE emits one apt-get install RUN per requirement plus update / clean", {
  skip_if(is_rdevel, "skip on R-devel")
  out <- dock_from_renv(
    lockfile = the_lockfile,
    FROM = "rocker/verse",
    renv_version = "0.0.0",
    sysreqs = FALSE,
    expand = TRUE,
    extra_sysreqs = c("libsodium-dev", "libxml2-dev")
  )
  df <- out$Dockerfile
  expect_true(any(df == "RUN apt-get update -y"))
  expect_true(any(df == "RUN apt-get install -y libsodium-dev"))
  expect_true(any(df == "RUN apt-get install -y libxml2-dev"))
  expect_true(any(df == "RUN rm -rf /var/lib/apt/lists/*"))
})

test_that(".patch_rprofile_for_ppm returns invisibly when no Rprofile.site tee line is present", {
  # Build a minimal dock that does NOT contain the `tee /usr/local/lib/R/etc/Rprofile.site` line
  # so the defensive `length(rps_idx) != 1L` guard fires. The function must
  # return invisible(NULL) without altering the dock.
  dock <- Dockerfile$new(FROM = "plop")
  before <- dock$Dockerfile
  res <- dockerfiler:::.patch_rprofile_for_ppm(
    dock,
    repos = c(CRAN = "https://packagemanager.posit.co/cran/latest")
  )
  expect_null(res)
  expect_identical(dock$Dockerfile, before)
})

test_that(".patch_rprofile_for_ppm returns invisibly when more than one Rprofile.site tee line is present", {
  # The other half of the `length(rps_idx) != 1L` guard: when a dock
  # already carries two RUN lines that match the Rprofile.site tee
  # pattern (which would happen if a caller injected an extra
  # configuration RUN before the patch), the function must refuse to
  # rewrite either of them.
  dock <- Dockerfile$new(FROM = "plop")
  dock$RUN(
    "echo \"options(repos = c(CRAN = 'https://packagemanager.posit.co/cran/latest'), download.file.method = 'libcurl', Ncpus = 4)\" | tee /usr/local/lib/R/etc/Rprofile.site | tee /usr/lib/R/etc/Rprofile.site"
  )
  dock$RUN(
    "echo \"options(repos = c(CRAN = 'https://packagemanager.posit.co/cran/latest'), download.file.method = 'libcurl', Ncpus = 4)\" | tee /usr/local/lib/R/etc/Rprofile.site | tee /usr/lib/R/etc/Rprofile.site"
  )
  before <- dock$Dockerfile

  res <- dockerfiler:::.patch_rprofile_for_ppm(
    dock,
    repos = c(CRAN = "https://packagemanager.posit.co/cran/latest")
  )

  expect_null(res)
  expect_identical(dock$Dockerfile, before)
})

test_that("dock_from_renv with user = NULL keeps the cache at /root and emits no chown / no USER / no useradd", {
  skip_if(is_rdevel, "skip on R-devel")
  out <- dock_from_renv(
    lockfile = the_lockfile,
    FROM = "rocker/verse",
    user = NULL,
    renv_version = "0.0.0"
  )
  df <- paste(out$Dockerfile, collapse = "\n")
  expect_match(df, "ARG RENV_PATHS_CACHE=/root/\\.cache/R/renv")
  expect_false(grepl("\\bUSER\\b", df))
  expect_false(grepl("chown", df))
  expect_false(grepl("useradd", df))
})

test_that("dock_from_renv with default user emits a defensive useradd at the top of the Dockerfile", {
  skip_if(is_rdevel, "skip on R-devel")
  out <- dock_from_renv(
    lockfile = the_lockfile,
    FROM = "rocker/verse",
    renv_version = "0.0.0"
  )
  lines <- out$Dockerfile

  # The defensive useradd must be early, well before any RUN that
  # might touch the user. Allowing for the FROM line + a couple of
  # ARG/ENV directives, the useradd should appear within the first
  # few non-FROM lines.
  useradd_idx <- grep(
    "id -u rstudio.*useradd -m -d /home/rstudio -s /bin/bash rstudio",
    lines
  )
  expect_length(useradd_idx, 1L)

  # The useradd RUN must precede any chown / USER / install RUN.
  install_idx <- grep("install\\.packages|install_version", lines)
  user_idx <- grep("^USER ", lines)
  if (length(install_idx) > 0L) {
    expect_lt(useradd_idx, min(install_idx))
  }
  if (length(user_idx) > 0L) {
    expect_lt(useradd_idx, min(user_idx))
  }
})

test_that("dock_from_renv with user = 'rstudio' auto-derives the cache to /home/rstudio/", {
  skip_if(is_rdevel, "skip on R-devel")
  out <- dock_from_renv(
    lockfile = the_lockfile,
    FROM = "rocker/verse",
    user = "rstudio",
    renv_version = "0.0.0"
  )
  df <- paste(out$Dockerfile, collapse = "\n")
  expect_match(df, "ARG RENV_PATHS_CACHE=/home/rstudio/\\.cache/R/renv")
  expect_match(df, 'chown -R rstudio:rstudio "\\$\\{RENV_PATHS_CACHE\\}"')
})

test_that("dock_from_renv with user = 'rstudio' orders RUNs correctly: apt-get -> chown -> USER -> renv::restore", {
  skip_if(is_rdevel, "skip on R-devel")
  skip_on_os("mac")
  out <- dock_from_renv(
    lockfile = the_lockfile,
    FROM = "rocker/verse",
    user = "rstudio",
    renv_version = "0.0.0"
  )
  lines <- out$Dockerfile

  apt_idx <- grep("apt-get install", lines)
  chown_idx <- grep("chown -R rstudio:rstudio", lines)
  user_idx <- grep("^USER rstudio$", lines)
  restore_idx <- grep("renv::restore", lines)

  expect_gt(length(chown_idx), 0L)
  expect_gt(length(user_idx), 0L)
  expect_gt(length(restore_idx), 0L)

  # apt-get must come BEFORE USER (apt-get requires root).
  expect_true(all(apt_idx < user_idx[1]))

  # chown must come BEFORE USER (chown requires root and must
  # run before the privilege drop).
  expect_true(all(chown_idx < user_idx[1]))

  # USER must come BEFORE renv::restore (the cache mount target
  # was chowned to <user>; the restore needs to write to it).
  expect_true(all(user_idx < restore_idx))
})

test_that("dock_from_renv with user + explicit renv_paths_cache honors the explicit path and chowns it", {
  skip_if(is_rdevel, "skip on R-devel")
  out <- dock_from_renv(
    lockfile = the_lockfile,
    FROM = "rocker/verse",
    user = "myapp",
    renv_paths_cache = "/srv/myapp/cache",
    renv_version = "0.0.0"
  )
  df <- paste(out$Dockerfile, collapse = "\n")
  expect_match(df, "ARG RENV_PATHS_CACHE=/srv/myapp/cache")
  expect_match(df, 'chown -R myapp:myapp "\\$\\{RENV_PATHS_CACHE\\}"')
})

test_that("dock_from_renv rejects shell-injection-prone user values", {
  # `user` is interpolated into Dockerfile RUN commands (id, useradd,
  # chown). Without validation, a caller could pass a string with shell
  # metacharacters or whitespace and either break the generated
  # Dockerfile or inject arbitrary commands at docker build time.
  skip_if(is_rdevel, "skip on R-devel")

  expect_error(
    dock_from_renv(
      lockfile = the_lockfile,
      FROM = "rocker/verse",
      user = "; rm -rf /",
      renv_version = "0.0.0"
    ),
    "POSIX username"
  )
  expect_error(
    dock_from_renv(
      lockfile = the_lockfile,
      FROM = "rocker/verse",
      user = "bad user",
      renv_version = "0.0.0"
    ),
    "POSIX username"
  )
  expect_error(
    dock_from_renv(
      lockfile = the_lockfile,
      FROM = "rocker/verse",
      user = "user$(echo pwned)",
      renv_version = "0.0.0"
    ),
    "POSIX username"
  )
  expect_error(
    dock_from_renv(
      lockfile = the_lockfile,
      FROM = "rocker/verse",
      user = "1starts-with-digit",
      renv_version = "0.0.0"
    ),
    "POSIX username"
  )
  # A colon would break the chown -R user:user round-trip if it ever
  # got through the validation -- exercise it directly.
  expect_error(
    dock_from_renv(
      lockfile = the_lockfile,
      FROM = "rocker/verse",
      user = "foo:bar",
      renv_version = "0.0.0"
    ),
    "POSIX username"
  )
  # Non-character / wrong length must also fail with the same path.
  expect_error(
    dock_from_renv(
      lockfile = the_lockfile,
      FROM = "rocker/verse",
      user = c("alice", "bob"),
      renv_version = "0.0.0"
    ),
    "POSIX username"
  )
})

test_that("dock_from_renv emits a single RUN combining mkdir and chown with a quoted cache path", {
  # Two safety/hygiene properties locked here:
  # 1. mkdir + chown must run as a single Dockerfile RUN (one image
  #    layer) joined with `&&`.
  # 2. The interpolated `${RENV_PATHS_CACHE}` must be double-quoted so a
  #    build-arg containing whitespace or shell metacharacters cannot
  #    break the command or inject (the env var is caller-overridable
  #    via `--build-arg RENV_PATHS_CACHE=...`).
  skip_if(is_rdevel, "skip on R-devel")
  out <- dock_from_renv(
    lockfile = the_lockfile,
    FROM = "rocker/verse",
    user = "rstudio",
    renv_version = "0.0.0"
  )
  df <- paste(out$Dockerfile, collapse = "\n")

  # Single combined RUN (one layer):
  expect_match(
    df,
    'RUN mkdir -p "\\$\\{RENV_PATHS_CACHE\\}" && chown -R rstudio:rstudio "\\$\\{RENV_PATHS_CACHE\\}"'
  )

  # No leftover unquoted standalone mkdir / chown:
  expect_false(grepl("RUN mkdir -p \\$\\{RENV_PATHS_CACHE\\}\\s*$", df))
  expect_false(
    grepl(
      "^RUN chown -R [^:]+:[^ ]+ \\$\\{RENV_PATHS_CACHE\\}\\s*$",
      df,
      perl = TRUE
    )
  )
})

test_that("dock_from_renv with user = 'kevin' parameterises the useradd, cache and chown on 'kevin'", {
  # Locks the invariant that the user-handling logic is fully
  # parameterised on `user` and not hardcoded on "rstudio". Without
  # this, a future refactor that accidentally hardcodes the username
  # would silently regress for any non-rstudio caller.
  skip_if(is_rdevel, "skip on R-devel")
  out <- dock_from_renv(
    lockfile = the_lockfile,
    FROM = "rocker/verse",
    user = "kevin",
    renv_version = "0.0.0"
  )
  df <- paste(out$Dockerfile, collapse = "\n")
  expect_match(df, "id -u kevin >/dev/null 2>&1 \\|\\| useradd -m -d /home/kevin -s /bin/bash kevin")
  expect_match(df, "ARG RENV_PATHS_CACHE=/home/kevin/\\.cache/R/renv")
  expect_match(df, 'chown -R kevin:kevin "\\$\\{RENV_PATHS_CACHE\\}"')
  # The USER directive lives on its own line; check the line vector
  # rather than the paste-collapsed single string.
  expect_true("USER kevin" %in% out$Dockerfile)
  # Negative invariant: no hardcoded "rstudio" leaked into a user-scope
  # context (cran.rstudio.com in the default repos URL is fine and
  # excluded explicitly).
  expect_false(any(grepl("\\brstudio\\b(?!\\.com)", out$Dockerfile, perl = TRUE)))
})

test_that("dock_from_renv rejects shell-active metacharacters in repos URL even though the URL grammar tolerates them", {
  # `.validate_repos` doubles as the escape primitive for the
  # double-quoted shell `echo "options(repos = ...)"` wrapper. Inside
  # `"..."`, the shell still interprets `$`, backtick, backslash and
  # `!`. A repos URL with `$(...)` would expand to a command at
  # `docker build` time even though the URL itself is otherwise
  # well-formed.
  skip_if(is_rdevel, "skip on R-devel")
  expect_error(
    dock_from_renv(
      lockfile = the_lockfile,
      FROM = "rocker/verse",
      user = NULL,
      repos = c(CRAN = "https://evil$(id).example.com"),
      renv_version = "0.0.0"
    ),
    "repos"
  )
})

test_that("dock_from_renv accepts a private-registry FROM with host:port/image", {
  # The Docker reference grammar permits `<host>:<port>/<image>`.
  # The validator must not reject this common private-registry form.
  skip_if(is_rdevel, "skip on R-devel")
  expect_silent(
    dockerfiler:::.validate_FROM("localhost:5000/myimage")
  )
  expect_silent(
    dockerfiler:::.validate_FROM("registry.example.com:443/org/img:1.2")
  )
  expect_silent(
    dockerfiler:::.validate_FROM("rocker/r-base:4.5")
  )
  expect_silent(
    dockerfiler:::.validate_FROM(
      "rocker/r-base@sha256:abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789"
    )
  )
})

test_that("dock_from_renv rejects shell-metacharacter / unsafe values across user-supplied params", {
  skip_if(is_rdevel, "skip on R-devel")

  # use_pak: scalar logical. A non-logical value would be interpolated raw
  # into `echo "options(renv.config.pak.enabled = %s, ...)"`, breaking
  # the outer shell quoting and allowing command substitution at build
  # time.
  expect_error(
    dock_from_renv(
      lockfile = the_lockfile,
      FROM = "rocker/verse",
      user = NULL,
      use_pak = 'TRUE) ; system("evil") ; #',
      renv_version = "0.0.0"
    ),
    "use_pak"
  )

  # names(repos): must be simple identifiers. `dput()` would otherwise
  # wrap shell-unsafe names in backticks, which inside the outer
  # double-quoted `echo "..."` triggers command substitution.
  expect_error(
    dock_from_renv(
      lockfile = the_lockfile,
      FROM = "rocker/verse",
      user = NULL,
      repos = c(`CRAN; system('evil')` = "https://cran.rstudio.com/"),
      renv_version = "0.0.0"
    ),
    "names\\(repos\\)"
  )

  # AS: docker build-stage name. Newlines or shell metacharacters
  # would break the `FROM <X> AS <Y>` directive.
  expect_error(
    dock_from_renv(
      lockfile = the_lockfile,
      FROM = "rocker/verse",
      AS = "stage1\nRUN evil",
      user = NULL,
      renv_version = "0.0.0"
    ),
    "`AS`"
  )

  # extra_sysreqs: each element must be a Debian package name.
  expect_error(
    dock_from_renv(
      lockfile = the_lockfile,
      FROM = "rocker/verse",
      user = NULL,
      extra_sysreqs = "libfoo; rm -rf /",
      renv_version = "0.0.0"
    ),
    "extra_sysreqs"
  )

  # NA in vector inputs must not crash the validator with
  # "missing value where TRUE/FALSE needed"; treat as invalid and
  # raise the same clear message as other malformed entries.
  expect_error(
    dock_from_renv(
      lockfile = the_lockfile,
      FROM = "rocker/verse",
      user = NULL,
      extra_sysreqs = c("libcurl", NA_character_),
      renv_version = "0.0.0"
    ),
    "extra_sysreqs"
  )
  expect_error(
    dock_from_renv(
      lockfile = the_lockfile,
      FROM = "rocker/verse",
      user = NULL,
      repos = c(CRAN = NA_character_),
      renv_version = "0.0.0"
    ),
    "repos"
  )
  expect_error(
    dock_from_renv(
      lockfile = the_lockfile,
      FROM = "rocker/verse",
      user = NULL,
      repos = setNames(
        "https://cran.rstudio.com/",
        NA_character_
      ),
      renv_version = "0.0.0"
    ),
    "names\\(repos\\)"
  )

  # repos: each URL must look like a real http(s) URL.
  expect_error(
    dock_from_renv(
      lockfile = the_lockfile,
      FROM = "rocker/verse",
      user = NULL,
      repos = c(CRAN = "https://evil'); cat /etc/passwd; #"),
      renv_version = "0.0.0"
    ),
    "repos"
  )

  # renv_version: must look like a version string. Anything else would
  # be interpolated raw into `R -e 'install_version("renv", version =
  # "<x>")'` and could break the inner quoting.
  expect_error(
    dock_from_renv(
      lockfile = the_lockfile,
      FROM = "rocker/verse",
      user = NULL,
      renv_version = '"); system("evil"); #'
    ),
    "renv_version"
  )

  # FROM: docker image reference.
  expect_error(
    dock_from_renv(
      lockfile = the_lockfile,
      FROM = "rocker/verse\nRUN evil",
      user = NULL,
      renv_version = "0.0.0"
    ),
    "FROM"
  )

  # renv_paths_cache: absolute path, no shell metacharacters or newlines.
  expect_error(
    dock_from_renv(
      lockfile = the_lockfile,
      FROM = "rocker/verse",
      user = NULL,
      renv_paths_cache = "/foo\nRUN evil",
      renv_version = "0.0.0"
    ),
    "renv_paths_cache"
  )
})

test_that("dock_from_renv rejects a lockfile path whose basename contains shell metacharacters", {
  skip_if(is_rdevel, "skip on R-devel")
  # Spaces in the basename would break the COPY directive
  # (`COPY foo bar.lock renv.lock` parses as src=foo, dst=bar.lock).
  bad <- tempfile(pattern = "lock with space ")
  file.copy(the_lockfile, bad)
  on.exit(unlink(bad), add = TRUE)
  expect_error(
    dock_from_renv(
      lockfile = bad,
      FROM = "rocker/verse",
      user = NULL,
      renv_version = "0.0.0"
    ),
    "lockfile"
  )
})

test_that("dock_from_renv validates the renv version read from the lockfile, not only the user-supplied one", {
  skip_if(is_rdevel, "skip on R-devel")
  # `renv_version` is interpolated raw into the generated
  # `R -e 'remotes::install_version("renv", version = "<x>")'` line, which
  # runs as root at `docker build` time. `.validate_renv_version()` must be
  # applied to the value resolved from `lock$Packages$renv$Version` (an
  # untrusted lockfile a user may have received from a colleague, a vendored
  # project, or a CI cache), not only to a user-supplied `renv_version=`.
  # A crafted lockfile carrying `'1.0.0"); system("..."); ("'` would
  # otherwise break out of the inner R string and execute arbitrary code.
  lock <- jsonlite::read_json(
    system.file("renv_with_1.0.0.lock", package = "dockerfiler"),
    simplifyVector = TRUE,
    simplifyDataFrame = FALSE,
    simplifyMatrix = FALSE
  )
  lock$Packages$renv$Version <- '1.0.0"); system("touch /tmp/dockerfiler_pwned"); ("'
  malicious_lf <- file.path(dir_build, "malicious-renv.lock")
  jsonlite::write_json(lock, path = malicious_lf, auto_unbox = TRUE, pretty = TRUE)
  on.exit(unlink(malicious_lf), add = TRUE)

  expect_error(
    dock_from_renv(
      lockfile = malicious_lf,
      FROM = "rocker/verse",
      user = NULL,
      sysreqs = FALSE
      # NOTE: no `renv_version =` -> the value comes from the lockfile.
    ),
    "renv_version"
  )
})

unlink(dir_build, recursive = TRUE)

