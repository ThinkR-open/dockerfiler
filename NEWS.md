# dockerfile 0.2.3

- remove sysreqs.r-hub.io to use {pak} instead for system requirement detection
- move from `pak::pkg_system_requirements` to `pak::pkg_sysreqs()` thanks to @B0ydT 
- `dock_from_renv` allow to specify user to use in Dockerfile
- the `dependencies` parameter in `dock_from_renv` if set to `TRUE` will install required dependencies plus optional and development dependencies. defaut is `NA` only required (hard) dependencies,
- Set the minimum version of the {pak} package to 0.6.0. 
- Parameterize the `sysreqs_platform` used to find system dependencies in pkg_sysreqs (only debian/ubuntu based images are supported)


# dockerfiler 0.2.2

- fix : create a `use_pak` parameters in `dock_from_renv` to set `renv.config.pak.enabled = FALSE` instead of `renv.config.pak.enabled = TRUE` to avoid issues with {pak} during `renv::restore()`

- feat: use of {memoise} to cache call to `pak::pkg_system_requirements`

- fix : dont depend anymore  to {renv} use an internalised {renv} version (1.0.3) 

- fix : remove `renv:::lockfile` and use `lockfile_read` instead

- feat: Added `dock_from_renv()`, to create a Dockerfile from a renv.lock file (@JosiahParry, @statnmap)

- feat: Added `parse_dockerfile()`, to Create a Dockerfile object from a Dockerfile file (@JosiahParry)

- feat: Added `renv_version` parameter to `dock_from_renv` to be able to fix the renv version to use during `renv::restore()` (@campbead)


# dockerfiler 0.2.0 

- fix: graceful failing in case no internet

- fix: the dedicated `compact_sysreqs` function allow to deal with 'complex' sysreqs, such as chromimum installation

- feat: add jammy ubuntu distro in available distro

# dockerfiler 0.1.4

* new version of `dock_from_desc()`

# dockerfiler 0.1.3.9000

* Corrected bug in `rthis()`

# dockerfiler 0.1.3

* Added the `add_after()` R6 method
* Added `dock_from_desc()`, to create a Dockerfile from a DESCRIPTION
