
<!-- README.md is generated from README.Rmd. Please edit that file -->
<!-- badges: start -->

[![R-CMD-check](https://github.com/ThinkR-open/dockerfiler/workflows/R-CMD-check/badge.svg)](https://github.com/ThinkR-open/dockerfiler/actions)
[![Coverage
status](https://codecov.io/gh/ThinkR-open/dockerfiler/branch/master/graph/badge.svg)](https://codecov.io/github/ThinkR-open/dockerfiler?branch=master)
<!-- badges: end -->

# `{dockerfiler}`

Easy Dockerfile Creation from R.

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

Wrap your raw R Code inside the `r()` function to turn it into a bash
command with `R -e`.

``` r
my_dock$RUN(r(install.packages("attempt", repo = "http://cran.irsn.fr/")))
```

Classical Docker stuffs:

``` r
my_dock$RUN("mkdir /usr/scripts")
my_dock$RUN("cd /usr/scripts")
my_dock$COPY("plumberfile.R", "/usr/scripts/plumber.R")
my_dock$COPY("torun.R", "/usr/scripts/torun.R")
my_dock$EXPOSE(8000)
my_dock$CMD("Rscript /usr/scripts/torun.R ")
```

See your Dockerfile :

``` r
my_dock
#> FROM rocker/r-base
#> MAINTAINER Colin FAY <contact@colinfay.me>
#> RUN R -e 'install.packages("attempt", repo = "http://cran.irsn.fr/")'
#> RUN mkdir /usr/scripts
#> RUN cd /usr/scripts
#> COPY plumberfile.R /usr/scripts/plumber.R
#> COPY torun.R /usr/scripts/torun.R
#> EXPOSE 8000
#> CMD Rscript /usr/scripts/torun.R
```

If you’ve made a mistake in your script, you can switch lines with the
`switch_cmd` method. This function takes as arguments the positions of
the two cmd you want to switch :

``` r
# Switch line 8 and 7
my_dock$switch_cmd(8, 7)
my_dock
#> FROM rocker/r-base
#> MAINTAINER Colin FAY <contact@colinfay.me>
#> RUN R -e 'install.packages("attempt", repo = "http://cran.irsn.fr/")'
#> RUN mkdir /usr/scripts
#> RUN cd /usr/scripts
#> COPY plumberfile.R /usr/scripts/plumber.R
#> EXPOSE 8000
#> COPY torun.R /usr/scripts/torun.R
#> CMD Rscript /usr/scripts/torun.R
```

You can also remove a cmd with `remove_cmd`:

``` r
my_dock$remove_cmd(8)
my_dock
#> FROM rocker/r-base
#> MAINTAINER Colin FAY <contact@colinfay.me>
#> RUN R -e 'install.packages("attempt", repo = "http://cran.irsn.fr/")'
#> RUN mkdir /usr/scripts
#> RUN cd /usr/scripts
#> COPY plumberfile.R /usr/scripts/plumber.R
#> EXPOSE 8000
#> CMD Rscript /usr/scripts/torun.R
```

This also works with a vector:

``` r
my_dock$remove_cmd(5:7)
my_dock
#> FROM rocker/r-base
#> MAINTAINER Colin FAY <contact@colinfay.me>
#> RUN R -e 'install.packages("attempt", repo = "http://cran.irsn.fr/")'
#> RUN mkdir /usr/scripts
#> CMD Rscript /usr/scripts/torun.R
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

## Create a Dockerfile from a DESCRIPTION

You can use a DESCRIPTION file to create a Dockerfile that installs the
dependencies and the package.

``` r
my_dock <- dock_from_desc("DESCRIPTION")
#> ℹ Please wait while we compute system requirements...
#> ✓ Done
#> • .dockerignore already present, skipping its creation.
my_dock
#> FROM rocker/r-ver:4.1.2
#> RUN apt-get update && apt-get install -y  git-core libcurl4-openssl-dev libgit2-dev libicu-dev libssl-dev make pandoc pandoc-citeproc && rm -rf /var/lib/apt/lists/*
#> RUN echo "options(repos = c(CRAN = 'https://cran.rstudio.com/'), download.file.method = 'libcurl', Ncpus = 4)" >> /usr/local/lib/R/etc/Rprofile.site
#> RUN R -e 'install.packages("remotes")'
#> RUN Rscript -e 'remotes::install_version("glue",upgrade="never", version = "1.6.1")'
#> RUN Rscript -e 'remotes::install_version("cli",upgrade="never", version = "3.1.1")'
#> RUN Rscript -e 'remotes::install_version("R6",upgrade="never", version = "2.5.1")'
#> RUN Rscript -e 'remotes::install_version("desc",upgrade="never", version = "1.4.0")'
#> RUN Rscript -e 'remotes::install_version("jsonlite",upgrade="never", version = "1.7.3")'
#> RUN Rscript -e 'remotes::install_version("knitr",upgrade="never", version = "1.37")'
#> RUN Rscript -e 'remotes::install_version("fs",upgrade="never", version = "1.5.2")'
#> RUN Rscript -e 'remotes::install_version("testthat",upgrade="never", version = "3.1.2")'
#> RUN Rscript -e 'remotes::install_version("rmarkdown",upgrade="never", version = "2.11")'
#> RUN Rscript -e 'remotes::install_version("usethis",upgrade="never", version = "2.1.5")'
#> RUN Rscript -e 'remotes::install_version("renv",upgrade="never", version = "0.15.2")'
#> RUN Rscript -e 'remotes::install_version("remotes",upgrade="never", version = "2.4.2")'
#> RUN Rscript -e 'remotes::install_version("pkgbuild",upgrade="never", version = "1.3.1")'
#> RUN Rscript -e 'remotes::install_version("pak",upgrade="never", version = "0.2.0")'
#> RUN Rscript -e 'remotes::install_version("attempt",upgrade="never", version = "0.3.1")'
#> RUN mkdir /build_zone
#> ADD . /build_zone
#> WORKDIR /build_zone
#> RUN R -e 'remotes::install_local(upgrade="never")'
#> RUN rm -rf /build_zone

my_dock$CMD(r(library(dockerfiler)))

my_dock$add_after(
  cmd = "RUN R -e 'remotes::install_cran(\"rlang\")'", 
  after = 3
)
my_dock
#> FROM rocker/r-ver:4.1.2
#> RUN apt-get update && apt-get install -y  git-core libcurl4-openssl-dev libgit2-dev libicu-dev libssl-dev make pandoc pandoc-citeproc && rm -rf /var/lib/apt/lists/*
#> RUN echo "options(repos = c(CRAN = 'https://cran.rstudio.com/'), download.file.method = 'libcurl', Ncpus = 4)" >> /usr/local/lib/R/etc/Rprofile.site
#> RUN R -e 'remotes::install_cran("rlang")'
#> RUN R -e 'install.packages("remotes")'
#> RUN Rscript -e 'remotes::install_version("glue",upgrade="never", version = "1.6.1")'
#> RUN Rscript -e 'remotes::install_version("cli",upgrade="never", version = "3.1.1")'
#> RUN Rscript -e 'remotes::install_version("R6",upgrade="never", version = "2.5.1")'
#> RUN Rscript -e 'remotes::install_version("desc",upgrade="never", version = "1.4.0")'
#> RUN Rscript -e 'remotes::install_version("jsonlite",upgrade="never", version = "1.7.3")'
#> RUN Rscript -e 'remotes::install_version("knitr",upgrade="never", version = "1.37")'
#> RUN Rscript -e 'remotes::install_version("fs",upgrade="never", version = "1.5.2")'
#> RUN Rscript -e 'remotes::install_version("testthat",upgrade="never", version = "3.1.2")'
#> RUN Rscript -e 'remotes::install_version("rmarkdown",upgrade="never", version = "2.11")'
#> RUN Rscript -e 'remotes::install_version("usethis",upgrade="never", version = "2.1.5")'
#> RUN Rscript -e 'remotes::install_version("renv",upgrade="never", version = "0.15.2")'
#> RUN Rscript -e 'remotes::install_version("remotes",upgrade="never", version = "2.4.2")'
#> RUN Rscript -e 'remotes::install_version("pkgbuild",upgrade="never", version = "1.3.1")'
#> RUN Rscript -e 'remotes::install_version("pak",upgrade="never", version = "0.2.0")'
#> RUN Rscript -e 'remotes::install_version("attempt",upgrade="never", version = "0.3.1")'
#> RUN mkdir /build_zone
#> ADD . /build_zone
#> WORKDIR /build_zone
#> RUN R -e 'remotes::install_local(upgrade="never")'
#> RUN rm -rf /build_zone
#> CMD R -e 'library(dockerfiler)'
```

## Create a Dockerfile from renv.lock

-   Create renv.lock

``` r
dir_build <- tempfile(pattern = "renv")
dir.create(dir_build)

# Create a lockfile
the_lockfile <- file.path(dir_build, "renv.lock")
custom_packages <- c(
  # attachment::att_from_description(),
  "renv",
  "cli", "glue", #"golem",
  "shiny", "stats", "utils",
  "testthat",
  "knitr"
)
renv::snapshot(
  packages = custom_packages,
  lockfile = the_lockfile,
  prompt = FALSE)
```

-   Build Dockerfile

``` r
my_dock <- dock_from_renv(lockfile = the_lockfile,
                   distro = "focal",
                   FROM = "rocker/verse",
                   out_dir = dir_build
    )
#> Fetching system dependencies for 57 package records.
my_dock
#> FROM rocker/verse:4.1
#> RUN apt-get update -y
#> RUN apt-get install -y make
#> RUN apt-get install -y zlib1g-dev
#> RUN apt-get install -y libicu-dev
#> RUN apt-get install -y pandoc
#> RUN echo "options(renv.config.pak.enabled = TRUE, repos = c(RSPM = 'https://packagemanager.rstudio.com/all/__linux__/focal}/latest', CRAN = 'https://cran.rstudio.com/'), download.file.method = 'libcurl', Ncpus = 4)" >> /usr/local/lib/R/etc/Rprofile.site
#> COPY /tmp/Rtmpt2027C/renv157ef360a56354/renv.lock.dock renv.lock
#> RUN R -e "install.packages('renv')"
#> RUN R -e 'renv::restore()'
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
