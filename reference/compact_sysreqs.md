# Compact Sysreqs

Compact Sysreqs

## Usage

``` r
compact_sysreqs(
  pkg_installs,
  update_cmd = "apt-get update -y",
  install_cmd = "apt-get install -y",
  clean_cmd = "rm -rf /var/lib/apt/lists/*"
)
```

## Arguments

- pkg_installs:

  pkg_sysreqs as vector,
  [`pak::pkg_sysreqs`](https://pak.r-lib.org/reference/pkg_sysreqs.html)
  output

- update_cmd:

  command used to update packages, "apt-get update -y" by default

- install_cmd:

  command used to install packages, "apt-get install -y" by default

- clean_cmd:

  command used to clean package folder, "rm -rf /var/lib/apt/lists/\*"
  by default

## Value

vector of compacted command to run to install sysreqs

## Examples

``` r
pkg_installs <- list("apt-get install -y htop", "apt-get install -y top")
compact_sysreqs(pkg_installs)
#> [1] "apt-get update -y && apt-get install -y  htop top && rm -rf /var/lib/apt/lists/*"
```
