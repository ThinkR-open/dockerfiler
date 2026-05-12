# Turn an R expression into a shell `R -e '...'` call

Captures an R expression unevaluated and renders it as a single
shell-quoted `R -e '...'` string, suitable for a
[Dockerfile](https://thinkr-open.github.io/dockerfiler/reference/Dockerfile.md)
`$RUN()` directive.

## Usage

``` r
r(code)
```

## Arguments

- code:

  an R expression (captured unevaluated) to wrap.

## Value

a length-1 character string of the form `R -e '...'`, shell-quoted with
[`base::shQuote()`](https://rdrr.io/r/base/shQuote.html).

## Examples

``` r
r(print("yeay"))
#> R -e 'print("yeay")'
r(install.packages("plumber", repos = "http://cran.irsn.fr/"))
#> R -e 'install.packages("plumber", repos = "http://cran.irsn.fr/")'
```
