# Parse a Dockerfile

Create a Dockerfile object from a Dockerfile.

## Usage

``` r
parse_dockerfile(path)
```

## Arguments

- path:

  path to the Dockerfile

## Value

A Dockerfile object

## Examples

``` r
parse_dockerfile(system.file("Dockerfile", package = "dockerfiler"))
#> FROM debian:jessie
#> 
#> RUN apt-get update
#> RUN apt-get install -y r-base r-base-dev
#> 
```
