#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(dplyr))

traced_files <- tibble(fun_name=list.files(path="data/fuzz")) %>% mutate(pkg=stringr::str_replace(fun_name, "(.*)::.*", "\\1"))
extracted_scripts <- tibble(path=list.files(path="../data/extracted-code", full.names=T, recursive=T)) %>% mutate(pkg=basename(dirname(dirname(path)))) %>% filter(endsWith(path, ".R"))

scripts <- semi_join(extracted_scripts, traced_files, by="pkg")

cat(pull(scripts, path), sep="\n")
