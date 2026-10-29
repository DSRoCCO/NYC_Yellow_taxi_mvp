#!/usr/bin/env Rscript
source("renv/activate.R")
library(nycyellowtaximvp)
build_artifact_bundle()
message("Bundle creado en: ", Sys.getenv("NYC_TAXI_ARTIFACTS", unset = "artifacts"))
