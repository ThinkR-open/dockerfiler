# Get system requirements

This function retrieves information about the system requirements using
the
[`pak::pkg_sysreqs()`](https://pak.r-lib.org/reference/pkg_sysreqs.html).

## Usage

``` r
get_sysreqs(packages, quiet = TRUE, batch_n = 30)
```

## Arguments

- packages:

  character vector. Packages names.

- quiet:

  Boolean. If `TRUE` the function is quiet.

- batch_n:

  numeric. Number of simultaneous packages to ask.

## Value

A vector of system requirements.
