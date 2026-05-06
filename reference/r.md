# Turn an R call into an Unix call

Turn an R call into an Unix call

## Usage

``` r
r(code)
```

## Arguments

- code:

  the function to call

## Value

an unix R call

## Examples

``` r
r(print("yeay"))
#> R -e 'print("yeay")'
r(install.packages("plumber", repo = "http://cran.irsn.fr/"))
#> R -e 'install.packages("plumber", repo = "http://cran.irsn.fr/")'
```
