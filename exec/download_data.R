#!/usr/bin/env Rscript
source("renv/activate.R")
library(nycyellowtaximvp)
print(download_nyc_tlc_data())
