# signatr-experiment

This is a skeleton project for running signatr experiments.
The idea is to have an isolated environment in which one can run the fuzzer.

## Installation

### Experimental setup

``` sh
$ git clone ssh://git@github.com/PRL-PRG/signatr-experiment
$ cd signatr-experiment
```
**Important: all of the following commands should be run inside the cloned repository!**

### Docker image

If the docker image has not yet been created, run

```sh
$ make -C docker-image
```

In the following, we will use either:

```sh
$ command
```

or

```sh
[docker]$ command
```

indicating if a `command` shall be run directly or in the docker container.

To run a command in a docker container, you can either run:

```sh
$ ./in-docker.sh command
```

which will spawn a new disposable container which will be removed after the command is finished, or

```sh
$ ./in-docker.sh bash
```

which will spawn an interactive shell in the container.

### Dependencies

Get the dependencies. The reason why we do not put them yet in the image is that
we might want to have some local changes to them.

```sh
$ git clone ssh://git@github.com/yth/record-dev
$ git clone ssh://git@github.com/PRL-PRG/argtracer
$ git clone ssh://git@github.com/PRL-PRG/instrumentr
$ git clone ssh://git@github.com/PRL-PRG/runr
$ git clone ssh://git@github.com/PRL-PRG/signatr
```

Check out the c-api branch of instrumentr.

Install the dependencies, using the docker image!

``` sh
[docker]$ make libs
```

This should create a `library` directory with all the above libraries as well as with all their dependencies.

**Important: double check that you see your username!**

## Tasks

The `Makefile` drives the experiment.

### TL;DR

```sh
[docker]$ echo stringr > packages.txt
[docker]$ make install-packages
[docker]$ make trace
```

### Installing packages

Each of the experiment task relies on a **corpus of packages**.
This corpus is defined in the `packages.txt` file - one line per package.
To install new packages, run:

```sh
[docker]$ make install-packages
```

Note: it will not remove installed packages.

### Extract package runnable code

```sh
[docker]$ make extract-code
```

This shall extract all runnable code from the corpus packages.
The result will be in `run/extracted-code`.
Concretely, in `run/extracted-code/runnable-code.csv`:

```csv
package,file,type,language,blank,comment,code
stringr,tests/testthat-drv-case.R,tests,R,4,0,12
stringr,tests/testthat-drv-conv.R,tests,R,2,0,6
```

### Running extracted code

```sh
[docker]$ make run-code
```

This shall run all the extracted code.
The result will be in `run/run-code`.
Concretely, in `run/run-code/parallel.csv`:

```sh
cat run/run-code/parallel.csv
Seq,Host,Starttime,JobRuntime,Send,Receive,Exitval,Signal,Command,V1,Stdout,Stderr
1,:,1623677476.696,0.745,0,0,0,0," /home/krikava/Research/Projects/signatr/signatr-experiment/scripts/run-r-file.sh -t 35m /home/krikava/Research/Projects/signatr/signatr-experiment/run/runnable-code/stringr/tests/testthat-drv-case.R",stringr/tests/testthat-drv-case.R,,
```

The interesting part is in `Exitval` - non-zero means a failure.
If something is odd, the details should be in `run/run-code/<package>/<type>/<file>/task-output.txt`


### Wrap package runnable code

For tracing, we need to wrap all the extracted code with some bootstrapping code:

```sh
[docker]$ make wrap-code
```

This will use `scripts/wrap-template.R` to replace `.BODY.` with the actual file.
The result will be in `run/wrapped-code` and it is similar to extracted code.

### Trace

```sh
[docker]$ make trace
```

The results should be in `run/trace`.
Concretely, in `run/trace/parallel.csv` like in run code task.
The actual `db` will be in `run/trace/<package>/<type>/<file>/db`

