library(generatr)
library(sxpdb)
library(magrittr)
library(tibble)
library(stringr)

# Load the database.
value_db <- load_db("/mnt/ocfs_vol_00/cran_db-3/")
#
# # Also load the origins and meta dbs. Meta is currently unused, but will likely be in the future.
origins_db <- view_origins_db(value_db) %>% as_tibble
meta_db <- view_meta_db(value_db) %>% as_tibble

# To fuzz a package:
fuzz_every_fn_in_pkg("stringr", value_db, origins_db, meta_db, budget = 10^3) -> stringr__dfs
