
<!-- README.md is generated from README.Rmd. Please edit that file -->

<!-- badges: start -->

[![R-CMD-check](https://github.com/ThinkR-open/dockerfiler/workflows/R-CMD-check/badge.svg)](https://github.com/ThinkR-open/dockerfiler/actions)
[![Coverage
status](https://codecov.io/gh/ThinkR-open/dockerfiler/branch/master/graph/badge.svg)](https://app.codecov.io/github/ThinkR-open/dockerfiler?branch=master)
<!-- badges: end -->

# `{dockerfiler}`

The goal of `{dockerfiler}` is to provide an easy way to create
Dockerfiles from R.

## About

You’re reading the doc about version :

``` r
desc::desc_get_version()
#> [1] '0.2.5'
```

## Installation

You can install dockerfiler from GitHub with:

``` r
# install.packages("remotes")
remotes::install_github("ThinkR-open/dockerfiler")
```

Or from CRAN with :

``` r
install.packages("dockerfiler")
```

## Basic worflow

By default, Dockerfiles are created with `FROM "rocker/r-base"`.

You can set another FROM in `new()`

``` r
library(dockerfiler)
# Create a dockerfile template
my_dock <- Dockerfile$new()
my_dock$MAINTAINER("Colin FAY", "contact@colinfay.me")
```

Add comments to your Dockerfile

``` r
my_dock$COMMENT("Install required R package.")
```

Wrap your raw R Code inside the `r()` function to turn it into a bash
command with `R -e`.

``` r
my_dock$RUN(r(install.packages("attempt", repo = "http://cran.irsn.fr/")))
```

Classical Docker stuffs:

``` r
my_dock$COMMENT("Copy Plumber API and main script to container.")
my_dock$RUN("mkdir /usr/scripts")
my_dock$RUN("cd /usr/scripts")
my_dock$COPY("plumberfile.R", "/usr/scripts/plumber.R")
my_dock$COPY("torun.R", "/usr/scripts/torun.R")
my_dock$COMMENT("Expose the API port and run the main script when the container starts.")
my_dock$EXPOSE(8000)
my_dock$CMD("Rscript /usr/scripts/torun.R ")
```

See your Dockerfile :

``` r
my_dock
```

If you’ve made a mistake in your script, you can switch lines with the
`switch_cmd` method. This function takes as arguments the positions of
the two cmd you want to switch :

``` r
# Switch line 8 and 7
my_dock$switch_cmd(8, 7)
my_dock
```

You can also remove a cmd with `remove_cmd`:

``` r
my_dock$remove_cmd(8)
my_dock
```

This also works with a vector:

``` r
my_dock$remove_cmd(5:7)
my_dock
```

`add_after` add a command after a given line.

``` r
my_dock$add_after(
  cmd = "RUN R -e 'remotes::install_cran(\"rlang\")'",
  after = 3
)
```

Save your Dockerfile:

``` r
my_dock$write()
```

## Multi-stage dockerfile

Here is an example of generating a multi-stage Dockerfile directly from
R: we create two Dockerfile objects, one for the build stage (builder)
and one for the final stage (final), and then merge them into a single
file.

``` r
stage_1 <- Dockerfile$new(
  FROM = "alpine",AS ="builder"
)
stage_1$RUN('echo "Hi from builder" > /coucou.txt')

stage_2 <- Dockerfile$new(
  FROM = "ubuntu", AS = "final"
)
stage_2$COMMENT("copy /coucou.txt from builder to /truc.txt in final")
stage_2$COPY(from = "/coucou",to = "/truc.txt",force = TRUE, stage ="builder")
stage_2$RUN( "cat /truc.txt")

stage_1$write()
stage_2$write(append = TRUE)
#file.edit("Dockerfile")
```

## Create a Dockerfile from a DESCRIPTION

You can use a DESCRIPTION file to create a Dockerfile that installs the
dependencies and the package.

``` r
my_dock <- dock_from_desc("DESCRIPTION")
my_dock

my_dock$CMD(r(library(dockerfiler)))

my_dock$add_after(
  cmd = "RUN R -e 'remotes::install_cran(\"rlang\")'",
  after = 3
)
my_dock
```

## Create a Dockerfile from renv.lock

- Create renv.lock

``` r
dir_build <- tempfile(pattern = "renv")
dir.create(dir_build)

# Create a lockfile
the_lockfile <- file.path(dir_build, "renv.lock")
custom_packages <- c(
  # attachment::att_from_description(),
  "renv",
  "cli",
  "glue",
  "golem",
  "shiny",
  "stats",
  "utils",
  "testthat",
  "knitr"
)
renv::snapshot(
  packages = custom_packages,
  lockfile = the_lockfile,
  prompt = FALSE
)
```

- Build Dockerfile

``` r
my_dock <- dock_from_renv(
  lockfile = the_lockfile,
  distro = "focal",
  FROM = "rocker/verse"
)
my_dock
```

## Contact

Questions and feedbacks [welcome](mailto:contact@colinfay.me)!

You want to contribute ? Open a
[PR](https://github.com/ThinkR-open/dockerfiler/pulls) :) If you
encounter a bug or want to suggest an enhancement, please [open an
issue](https://github.com/ThinkR-open/dockerfiler/issues).

Please note that this project is released with a [Contributor Code of
Conduct](CODE_OF_CONDUCT.md). By participating in this project you agree
to abide by its terms.
