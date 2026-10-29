calendar_frame <- function(epoch) {
  x <- as.POSIXct(epoch, origin = "1970-01-01", tz = "UTC")
  data.frame(hour = factor(lubridate::hour(x), levels = 0:23), weekday = factor(lubridate::wday(x, week_start = 1), levels = 1:7), month = factor(lubridate::month(x), levels = 1:12))
}

fit_series_model <- function(series) {
  idx <- 169:nrow(series)
  features <- calendar_frame(series$epoch[idx])
  features$y <- log1p(series$trips[idx]); features$l1 <- log1p(series$trips[idx - 1]); features$l24 <- log1p(series$trips[idx - 24]); features$l168 <- log1p(series$trips[idx - 168])
  stats::lm(y ~ l1 + l24 + l168 + hour + weekday + month, data = features)
}

fit_seasonal_model <- function(series) {
  features <- calendar_frame(series$epoch)
  features$y <- log1p(series$trips)
  stats::lm(y ~ hour + weekday + month, data = features)
}

#' Build app artifacts from validated raw files and frozen evidence
#' @export
build_artifact_bundle <- function(raw_dir = raw_data_dir(), output_dir = artifact_dir(), reports_dir = file.path(project_root(), "reports")) {
  validation <- validate_raw_manifest(raw_dir)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  path <- gsub("'", "''", normalizePath(file.path(raw_dir, "*.parquet"), mustWork = FALSE), fixed = TRUE)
  DBI::dbExecute(con, sprintf("CREATE VIEW trips AS SELECT * FROM read_parquet('%s', union_by_name=true, filename=true)", path))
  valid <- "tpep_pickup_datetime IS NOT NULL AND strftime(tpep_pickup_datetime, '%Y-%m') = regexp_extract(filename, 'yellow_tripdata_([0-9]{4}-[0-9]{2})', 1)"
  used_zone_ids <- DBI::dbGetQuery(con, sprintf("SELECT DISTINCT CAST(PULocationID AS INTEGER) AS LocationID FROM trips WHERE %s AND PULocationID IS NOT NULL", valid))
  zone_lookup <- readr::read_csv(file.path(raw_dir, "taxi_zone_lookup.csv"), show_col_types = FALSE)
  valid_zones <- dplyr::semi_join(zone_lookup, used_zone_ids, by = "LocationID") |> dplyr::arrange(Borough, Zone)
  city <- DBI::dbGetQuery(con, sprintf("SELECT epoch(date_trunc('hour', tpep_pickup_datetime)) AS epoch, count(*) AS trips FROM trips WHERE %s AND tpep_pickup_datetime >= TIMESTAMP '2022-01-01' GROUP BY 1 ORDER BY 1", valid))
  zones <- readr::read_csv(file.path(reports_dir, "predictive_top_zones.csv"), show_col_types = FALSE)
  ids <- paste(zones$pickup_zone, collapse = ",")
  zone_rows <- DBI::dbGetQuery(con, sprintf("SELECT epoch(date_trunc('hour', tpep_pickup_datetime)) AS epoch, PULocationID AS pickup_zone, count(*) AS trips FROM trips WHERE %s AND tpep_pickup_datetime >= TIMESTAMP '2022-01-01' AND PULocationID IN (%s) GROUP BY 1,2 ORDER BY 1", valid, ids))
  grid <- data.frame(epoch = seq(min(city$epoch), max(city$epoch), by = 3600))
  series <- list(city = transform(merge(grid, city, by = "epoch", all.x = TRUE), trips = ifelse(is.na(trips), 0, trips)))
  for (z in zones$pickup_zone) { d <- dplyr::filter(zone_rows, pickup_zone == z)[c("epoch", "trips")]; series[[paste0("zone_", z)]] <- transform(merge(grid, d, by = "epoch", all.x = TRUE), trips = ifelse(is.na(trips), 0, trips)) }
  models <- lapply(series, fit_series_model)
  seasonal_models <- lapply(series, fit_seasonal_model)
  evidence_names <- c("monthly_city_profile.csv", "hour_weekday_profile.csv", "zone_regime_profile.csv", "data_quality_by_source_month.csv", "findings_register.csv", "predictive_gate.csv", "predictive_metrics.csv", "predictive_top_zones.csv")
  evidence <- lapply(evidence_names, function(x) readr::read_csv(file.path(reports_dir, x), show_col_types = FALSE)); names(evidence) <- sub("\\.csv$", "", evidence_names)
  cutoff <- format(as.POSIXct(max(city$epoch), origin = "1970-01-01", tz = "UTC"), "%Y-%m-%d %H:%M UTC")
  saveRDS(list(schema_version = "1.3", descriptive_coverage_start = "2019-01-01", cutoff = cutoff, evidence = evidence, valid_zones = valid_zones, raw_manifest_sha256 = sha256_file(file.path(raw_dir, "manifest.csv"))), file.path(output_dir, "app_data.rds"))
  saveRDS(list(schema_version = "1.3", predictive_coverage_start = "2022-01-01", cutoff = cutoff, models = models, seasonal_models = seasonal_models, series = series, zones = zones), file.path(output_dir, "forecast_bundle.rds"))
  write_csv(data.frame(schema_version = "1.3", descriptive_coverage_start = "2019-01-01", predictive_coverage_start = "2022-01-01", cutoff = cutoff, source_manifest_sha256 = sha256_file(file.path(raw_dir, "manifest.csv")), generated_utc = format(Sys.time(), tz = "UTC", usetz = TRUE), raw_files_validated = nrow(validation)), file.path(output_dir, "artifact_manifest.csv"))
  invisible(output_dir)
}
