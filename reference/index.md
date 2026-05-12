# Package index

## Dockerfile builders

High-level entry points that produce a `Dockerfile` object, either from
a project descriptor (DESCRIPTION, renv.lock) or by parsing an existing
Dockerfile. Most users start here.

- [`dock_from_desc()`](https://thinkr-open.github.io/dockerfiler/reference/dockerfiles.md)
  : Create a Dockerfile from a DESCRIPTION

- [`dock_from_renv()`](https://thinkr-open.github.io/dockerfiler/reference/dock_from_renv.md)
  :

  Create a Dockerfile from an `renv.lock` file

- [`parse_dockerfile()`](https://thinkr-open.github.io/dockerfiler/reference/parse_dockerfile.md)
  : Parse a Dockerfile

## Dockerfile R6 class

Low-level imperative API for building a `Dockerfile` directive by
directive. The high-level builders above are thin wrappers over this
class.

- [`Dockerfile`](https://thinkr-open.github.io/dockerfiler/reference/Dockerfile.md)
  : A Dockerfile template

## R-to-shell helper

Wrap an R expression into the shell-safe `R -e '...'` invocation used
inside a `RUN` directive.

- [`r()`](https://thinkr-open.github.io/dockerfiler/reference/r.md) :

  Turn an R expression into a shell `R -e '...'` call

## System requirements

Resolve and compact Debian/Ubuntu system dependencies for the R packages
your Dockerfile installs. Usually called internally by the builders;
exposed for advanced use.

- [`get_sysreqs()`](https://thinkr-open.github.io/dockerfiler/reference/get_sysreqs.md)
  : Get system requirements
- [`compact_sysreqs()`](https://thinkr-open.github.io/dockerfiler/reference/compact_sysreqs.md)
  : Compact Sysreqs

## Project setup

Helpers for the surrounding project (not the Dockerfile itself).

- [`docker_ignore_add()`](https://thinkr-open.github.io/dockerfiler/reference/docker_ignore_add.md)
  : Create a dockerignore file
