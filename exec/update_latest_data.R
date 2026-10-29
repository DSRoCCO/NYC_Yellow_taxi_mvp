#!/usr/bin/env Rscript
source("renv/activate.R")
library(nycyellowtaximvp)
print(download_latest_nyc_tlc_data())
