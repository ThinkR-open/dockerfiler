# A Dockerfile template

A Dockerfile template

A Dockerfile template

## Public fields

- `Dockerfile`:

  The dockerfile content.

## Methods

### Public methods

- [`Dockerfile$new()`](#method-Dockerfile-new)

- [`Dockerfile$RUN()`](#method-Dockerfile-RUN)

- [`Dockerfile$ADD()`](#method-Dockerfile-ADD)

- [`Dockerfile$COPY()`](#method-Dockerfile-COPY)

- [`Dockerfile$WORKDIR()`](#method-Dockerfile-WORKDIR)

- [`Dockerfile$EXPOSE()`](#method-Dockerfile-EXPOSE)

- [`Dockerfile$VOLUME()`](#method-Dockerfile-VOLUME)

- [`Dockerfile$CMD()`](#method-Dockerfile-CMD)

- [`Dockerfile$LABEL()`](#method-Dockerfile-LABEL)

- [`Dockerfile$ENV()`](#method-Dockerfile-ENV)

- [`Dockerfile$ENTRYPOINT()`](#method-Dockerfile-ENTRYPOINT)

- [`Dockerfile$USER()`](#method-Dockerfile-USER)

- [`Dockerfile$ARG()`](#method-Dockerfile-ARG)

- [`Dockerfile$ONBUILD()`](#method-Dockerfile-ONBUILD)

- [`Dockerfile$STOPSIGNAL()`](#method-Dockerfile-STOPSIGNAL)

- [`Dockerfile$HEALTHCHECK()`](#method-Dockerfile-HEALTHCHECK)

- [`Dockerfile$SHELL()`](#method-Dockerfile-SHELL)

- [`Dockerfile$MAINTAINER()`](#method-Dockerfile-MAINTAINER)

- [`Dockerfile$custom()`](#method-Dockerfile-custom)

- [`Dockerfile$COMMENT()`](#method-Dockerfile-COMMENT)

- [`Dockerfile$print()`](#method-Dockerfile-print)

- [`Dockerfile$write()`](#method-Dockerfile-write)

- [`Dockerfile$switch_cmd()`](#method-Dockerfile-switch_cmd)

- [`Dockerfile$remove_cmd()`](#method-Dockerfile-remove_cmd)

- [`Dockerfile$add_after()`](#method-Dockerfile-add_after)

- [`Dockerfile$clone()`](#method-Dockerfile-clone)

------------------------------------------------------------------------

### Method `new()`

Create a new Dockerfile object.

#### Usage

    Dockerfile$new(FROM = "rocker/r-base", AS = NULL)

#### Arguments

- `FROM`:

  The base image.

- `AS`:

  The name of the image.

#### Returns

A Dockerfile object.

------------------------------------------------------------------------

### Method `RUN()`

Add a RUN command.

#### Usage

    Dockerfile$RUN(cmd)

#### Arguments

- `cmd`:

  The command to add.

#### Returns

the Dockerfile object, invisibly.

------------------------------------------------------------------------

### Method `ADD()`

Add a ADD command.

#### Usage

    Dockerfile$ADD(from, to, force = TRUE)

#### Arguments

- `from`:

  The source file.

- `to`:

  The destination file.

- `force`:

  If TRUE, overwrite the destination file.

#### Returns

the Dockerfile object, invisibly.

------------------------------------------------------------------------

### Method `COPY()`

Add a COPY command.

#### Usage

    Dockerfile$COPY(from, to, stage = NULL, force = TRUE)

#### Arguments

- `from`:

  The source file.

- `to`:

  The destination file.

- `stage`:

  Optional. Name of the build stage (e.g., `"builder"`) to copy files
  from. This corresponds to the `--from=` part in a Dockerfile COPY
  instruction (e.g., `COPY --from=builder /source /dest`). If `NULL`,
  the `--from=` argument is omitted.

- `force`:

  If TRUE, overwrite the destination file.

#### Returns

the Dockerfile object, invisibly.

------------------------------------------------------------------------

### Method `WORKDIR()`

Add a WORKDIR command.

#### Usage

    Dockerfile$WORKDIR(where)

#### Arguments

- `where`:

  The working directory.

#### Returns

the Dockerfile object, invisibly.

------------------------------------------------------------------------

### Method `EXPOSE()`

Add a EXPOSE command.

#### Usage

    Dockerfile$EXPOSE(port)

#### Arguments

- `port`:

  The port to expose.

#### Returns

the Dockerfile object, invisibly.

------------------------------------------------------------------------

### Method `VOLUME()`

Add a VOLUME command.

#### Usage

    Dockerfile$VOLUME(volume)

#### Arguments

- `volume`:

  The volume to add.

#### Returns

the Dockerfile object, invisibly.

------------------------------------------------------------------------

### Method `CMD()`

Add a CMD command.

#### Usage

    Dockerfile$CMD(cmd)

#### Arguments

- `cmd`:

  The command to add.

#### Returns

the Dockerfile object, invisibly.

------------------------------------------------------------------------

### Method `LABEL()`

Add a LABEL command.

#### Usage

    Dockerfile$LABEL(key, value)

#### Arguments

- `key, value`:

  The key and value of the label.

#### Returns

the Dockerfile object, invisibly.

------------------------------------------------------------------------

### Method `ENV()`

Add a ENV command.

#### Usage

    Dockerfile$ENV(key, value)

#### Arguments

- `key, value`:

  The key and value of the label.

#### Returns

the Dockerfile object, invisibly.

------------------------------------------------------------------------

### Method `ENTRYPOINT()`

Add a ENTRYPOINT command.

#### Usage

    Dockerfile$ENTRYPOINT(cmd)

#### Arguments

- `cmd`:

  The command to add.

#### Returns

the Dockerfile object, invisibly.

------------------------------------------------------------------------

### Method `USER()`

Add a USER command.

#### Usage

    Dockerfile$USER(user)

#### Arguments

- `user`:

  The user to add.

#### Returns

the Dockerfile object, invisibly.

------------------------------------------------------------------------

### Method `ARG()`

Add a ARG command.

#### Usage

    Dockerfile$ARG(arg, ahead = FALSE, default = NULL)

#### Arguments

- `arg`:

  The argument to add.

- `ahead`:

  If TRUE, add the argument at the beginning of the Dockerfile.

- `default`:

  Optional default value. When not `NULL`, the directive becomes
  `ARG <arg>=<default>`. Requires `arg` to be just the name (no embedded
  `=`); supplying both an inlined `=` in `arg` and a non-`NULL`
  `default` errors.

#### Returns

the Dockerfile object, invisibly.

------------------------------------------------------------------------

### Method `ONBUILD()`

Add a ONBUILD command.

#### Usage

    Dockerfile$ONBUILD(cmd)

#### Arguments

- `cmd`:

  The command to add.

#### Returns

the Dockerfile object, invisibly.

------------------------------------------------------------------------

### Method `STOPSIGNAL()`

Add a STOPSIGNAL command.

#### Usage

    Dockerfile$STOPSIGNAL(signal)

#### Arguments

- `signal`:

  The signal to add.

#### Returns

the Dockerfile object, invisibly.

------------------------------------------------------------------------

### Method `HEALTHCHECK()`

Add a HEALTHCHECK command.

#### Usage

    Dockerfile$HEALTHCHECK(check)

#### Arguments

- `check`:

  The check to add.

#### Returns

the Dockerfile object, invisibly.

------------------------------------------------------------------------

### Method `SHELL()`

Add a SHELL command.

#### Usage

    Dockerfile$SHELL(shell)

#### Arguments

- `shell`:

  The shell to add.

#### Returns

the Dockerfile object, invisibly.

------------------------------------------------------------------------

### Method `MAINTAINER()`

Add a MAINTAINER command.

#### Usage

    Dockerfile$MAINTAINER(name, email)

#### Arguments

- `name, email`:

  The name and email of the maintainer.

#### Returns

the Dockerfile object, invisibly.

------------------------------------------------------------------------

### Method `custom()`

Add a custom command.

#### Usage

    Dockerfile$custom(base, cmd)

#### Arguments

- `base, cmd`:

  The base and command to add.

#### Returns

the Dockerfile object, invisibly.

------------------------------------------------------------------------

### Method `COMMENT()`

Add a comment.

#### Usage

    Dockerfile$COMMENT(comment)

#### Arguments

- `comment`:

  The comment to add.

#### Returns

the Dockerfile object, invisibly.

------------------------------------------------------------------------

### Method [`print()`](https://rdrr.io/r/base/print.html)

Print the Dockerfile.

#### Usage

    Dockerfile$print()

#### Returns

used for side effect

------------------------------------------------------------------------

### Method [`write()`](https://rdrr.io/r/base/write.html)

Write the Dockerfile to a file.

#### Usage

    Dockerfile$write(as = "Dockerfile", append = FALSE)

#### Arguments

- `as`:

  The file to write to.

- `append`:

  boolean, if TRUE append to file.

#### Returns

used for side effect

------------------------------------------------------------------------

### Method `switch_cmd()`

Switch commands.

#### Usage

    Dockerfile$switch_cmd(a, b)

#### Arguments

- `a, b`:

  The commands to switch.

#### Returns

the Dockerfile object, invisibly.

------------------------------------------------------------------------

### Method `remove_cmd()`

Remove a command.

#### Usage

    Dockerfile$remove_cmd(where)

#### Arguments

- `where`:

  The commands to remove.

#### Returns

the Dockerfile object, invisibly.

------------------------------------------------------------------------

### Method `add_after()`

Add a command after another.

#### Usage

    Dockerfile$add_after(cmd, after)

#### Arguments

- `cmd`:

  The command to add.

- `after`:

  Where to add the cmd

#### Returns

the Dockerfile object, invisibly.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    Dockerfile$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
my_dock <- Dockerfile$new()
```
