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

By default, Dockerfiles are created with `FROM "rocker/r-base"`.

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
