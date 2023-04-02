# dockerfile 0.2.0 to 0.3.0

- fix: graceful failing in case no internet

- feat: Added `dock_from_renv()`, to create a Dockerfile from a renv.lock file (@JosiahParry, @statnmap)

- fix: the dedicated `compact_sysreqs` function allow to deal with 'complex' sysreqs, such as chromimum installation

- feat: add jammy ubuntu distro in available distro

# dockerfiler 0.1.4

* new version of `dock_from_desc()`

# dockerfiler 0.1.3.9000

* Corrected bug in `rthis()`

# dockerfiler 0.1.3

* Added the `add_after()` R6 method
* Added `dock_from_desc()`, to create a Dockerfile from a DESCRIPTION
