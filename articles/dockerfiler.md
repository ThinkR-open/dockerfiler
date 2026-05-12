# Getting started with dockerfiler

## dockerfiler

Easy Dockerfile Creation from R.

### Installation

You can install dockerfiler from GitHub with:

``` r

# install.packages("remotes")
remotes::install_github("ThinkR-open/dockerfiler")
```

Or from CRAN with :

``` r

install.packages("dockerfiler")
```

### Basic workflow

By default, `Dockerfile$new()` creates a Dockerfile with
`FROM "rocker/r-base"`. (The high-level generators
[`dock_from_desc()`](https://thinkr-open.github.io/dockerfiler/reference/dockerfiles.md)
and
[`dock_from_renv()`](https://thinkr-open.github.io/dockerfiler/reference/dock_from_renv.md)
use a different default: `rocker/r-ver` tagged with your R version; see
below.)

You can set another FROM in `new()`

``` r

library(dockerfiler)
# Create a dockerfile template
my_dock <- Dockerfile$new()
my_dock$MAINTAINER("Colin FAY", "contact@colinfay.me")
```

Wrap your raw R Code inside the
[`r()`](https://thinkr-open.github.io/dockerfiler/reference/r.md)
function to turn it into a bash command with `R -e`.

``` r

my_dock$RUN(r(install.packages("attempt", repos = "https://cloud.r-project.org")))
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
#> RUN R -e 'install.packages("attempt", repos = "https://cloud.r-project.org")'
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
#> RUN R -e 'install.packages("attempt", repos = "https://cloud.r-project.org")'
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
#> RUN R -e 'install.packages("attempt", repos = "https://cloud.r-project.org")'
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
#> RUN R -e 'install.packages("attempt", repos = "https://cloud.r-project.org")'
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

### Create a Dockerfile from a DESCRIPTION

You can use a DESCRIPTION file to create a Dockerfile that installs the
dependencies and the package.

``` r

my_dock <- dock_from_desc("DESCRIPTION")

my_dock$CMD(r(library(dockerfiler)))

my_dock$add_after(
  cmd = "RUN R -e 'remotes::install_cran(\"rlang\")'",
  after = 3
)
```

[`dock_from_desc()`](https://thinkr-open.github.io/dockerfiler/reference/dockerfiles.md)
defaults to `FROM rocker/r-ver:<your R version>` and pulls Linux
binaries from Posit Public Package Manager
(`https://p3m.dev/cran/latest`). Pass `FROM = "rocker/r-base"` or
`repos = c(CRAN = "https://cran.rstudio.com/")` to opt out.

### Create a Dockerfile from a renv.lock

If your project uses [renv](https://rstudio.github.io/renv/),
[`dock_from_renv()`](https://thinkr-open.github.io/dockerfiler/reference/dock_from_renv.md)
turns the `renv.lock` into a Dockerfile that restores the exact pinned
versions.

``` r

my_dock <- dock_from_renv(lockfile = "renv.lock")
my_dock
```

By default the generated Dockerfile is
`FROM rocker/r-ver:<your R version>` (multi-arch amd64 + arm64), pulls
Linux binaries from Posit Public Package Manager, and runs the container
as the non-root `rstudio` user. Pass `FROM = "rocker/r-base"`,
`repos = c(CRAN = "https://cran.rstudio.com/")`, or `user = NULL` to
restore the previous behaviour.

### Parse an existing Dockerfile

Already have a Dockerfile?
[`parse_dockerfile()`](https://thinkr-open.github.io/dockerfiler/reference/parse_dockerfile.md)
reads it back into a `Dockerfile` object you can edit and re-`$write()`.

``` r

my_dock <- parse_dockerfile("Dockerfile")
my_dock
my_dock$RUN(r(library(dockerfiler)))
my_dock$write("Dockerfile")
```
