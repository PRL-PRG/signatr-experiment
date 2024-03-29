# signatr-experiment

This is a skeleton project for running signatr experiments.

## Installation

``` sh
git clone ssh://git@github.com/PRL-PRG/signatr-experiment
cd signatr-experiment
```
**Important: all of the following commands should be run inside the cloned repository!**

- Install missing native dependencies (if applicable)

    ```sh
    sudo apt-get install libharfbuzz-dev libfribidi-dev
    ```

- Install R-4.0.2

    ```sh
    cd R-4.0.2
    curl https://cran.r-project.org/src/base/R-4/R-4.0.2.tar.gz | tar --strip-components=1 -xzf -
    ./build.sh
    ```

- Install R-dyntrace

    ```sh
    git clone -b r-4.0.2-signatr git@github.com:fikovnik/R-dyntrace
    cd R-dyntrace
    ./build
    ```

- Install R-dyntrace

    ```sh
    git clone -b r-4.0.2-signatr git@github.com:fikovnik/R-dyntrace R-dyntrace-dbg
    cd R-dyntrace-dbg
    ../build-R-dyntrace-dbg
    ```
- Clone runr

    ```
    git clone git@github.com:PRL-PRG/runr
    ```
    
- Install dependencies

    ```sh
    source ./env-4.0.2.sh
    ./runr/inst/install-cran-packages.R dependencies.txt
    ```

- Install runr

    ```sh
    make -C runr install
    ```

- Install tastr

    ```sh
    git clone git@github.com:PRL-PRG/tastr
    make -C tastr build
    ```

    Note that tastr needs [bison-3.5.4](https://ftp.gnu.org/gnu/bison/bison-3.5.4.tar.gz).

- Install injectr

    ```
    git clone git@github.com:PRL-PRG/injectr
    make -C injectr install
    ```

- Install contractr

    ```
    git clone -b devel git@github.com:PRL-PRG/contractr
    make -C contractr install
    ```

- Install sxpdb

    ```
    git clone git@github.com:PRL-PRG/sxpdb
    make -C sxpdb install
    ```

- Install generatr

    ```sh
    git clone -b devel git@github.com:reallyTG/generatr.git
    make -C generatr install
    ```

- Install argtracer

    ```sh
    source env-dyntrace.sh
    git clone git@github.com:PRL-PRG/argtracer
    make -C argtracer install
    ```

## Fuzzing

### Build the DB index

```R
> library(sxpdb)
> db <- open_db("/mnt/ocfs_vol_00/cran_db-3/", mode=TRUE)
> build_indexes(db)
NULL
> close_db(db)
```

Set up the environment:

```sh
source env-4.0.2.sh
```

The pipeline is in `pipeline-fuzzing/`.

## Generating database

Set up the right environment:

```sh 
source env-dyntrace.sh
```

The pipeline is in `pipeline-dbgen/`.
To run it, start R and

```R
targets::tar_make()
```

For using more cores (like, 10), do:

```R
tar_make_future(workers = 10)
```

The resulting merged database will be in `data/sxpdb/cran_db`.

Other by-products of the pipeline:

- `data/extracted-code` contains the extracted files (from tests, examples and vignettes) to be run to generate the values
- `data/sxpdb` contains also the individual databases, one for each source file that was run

