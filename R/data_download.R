#' Download and validate NYC TLC Yellow Taxi files
#' @param raw_dir destination directory
#' @param periods optional YYYY-MM periods; NULL downloads all manifest rows
#' @export
runtime_manifest_path <- function(raw_dir) file.path(raw_dir, "manifest_discovered.csv")

read_raw_manifest <- function(raw_dir) {
  manifest_path <- file.path(raw_dir, "manifest.csv")
  if (!file.exists(manifest_path)) stop("Falta manifest.csv; restaure el archivo versionado.", call. = FALSE)
  manifest <- readr::read_csv(manifest_path, show_col_types = FALSE)
  discovered_path <- runtime_manifest_path(raw_dir)
  if (file.exists(discovered_path)) manifest <- dplyr::bind_rows(manifest, readr::read_csv(discovered_path, show_col_types = FALSE))
  dplyr::arrange(dplyr::distinct(manifest, period, .keep_all = TRUE), period)
}

validate_manifest_row <- function(row, raw_dir) {
  dest <- file.path(raw_dir, row$file)
  file.exists(dest) && file.info(dest)$size == row$bytes && identical(tolower(sha256_file(dest)), tolower(row$sha256))
}

download_manifest_row <- function(row, raw_dir) {
  dest <- file.path(raw_dir, row$file)
  if (validate_manifest_row(row, raw_dir)) return(data.frame(period = row$period, status = "already_valid", file = row$file))
  tmp <- paste0(dest, ".download")
  ok <- tryCatch({ utils::download.file(row$source_url, tmp, mode = "wb", quiet = TRUE); TRUE }, error = function(e) FALSE)
  if (!ok || !file.exists(tmp)) return(data.frame(period = row$period, status = "download_failed", file = row$file))
  checked <- file.info(tmp)$size == row$bytes && identical(tolower(sha256_file(tmp)), tolower(row$sha256))
  if (!checked) { unlink(tmp); return(data.frame(period = row$period, status = "validation_failed", file = row$file)) }
  file.rename(tmp, dest)
  data.frame(period = row$period, status = "downloaded_valid", file = row$file)
}

download_nyc_tlc_data <- function(raw_dir = raw_data_dir(), periods = NULL) {
  manifest <- read_raw_manifest(raw_dir)
  if (!is.null(periods)) manifest <- dplyr::filter(manifest, period %in% periods)
  if (!nrow(manifest)) stop("No hay períodos solicitados en el manifiesto.", call. = FALSE)
  results <- lapply(seq_len(nrow(manifest)), function(i) download_manifest_row(manifest[i, ], raw_dir))
  dplyr::bind_rows(results)
}

#' Discover and download available official Yellow Taxi months after the frozen manifest
#' @param raw_dir destination directory
#' @param through latest month to probe, defaults to the prior calendar month
#' @export
download_latest_nyc_tlc_data <- function(raw_dir = raw_data_dir(), through = NULL) {
  frozen <- readr::read_csv(file.path(raw_dir, "manifest.csv"), show_col_types = FALSE)
  start <- as.Date(paste0(max(frozen$period), "-01"))
  start <- seq(start, by = "month", length.out = 2L)[2L]
  if (is.null(through)) through <- seq(as.Date(format(Sys.Date(), "%Y-%m-01")), by = "month", length.out = 2L)[1L] - 1L
  through <- as.Date(format(as.Date(through), "%Y-%m-01"))
  if (through < start) return(data.frame(period = character(), status = character(), file = character()))
  periods <- format(seq(start, through, by = "month"), "%Y-%m")
  known <- read_raw_manifest(raw_dir)
  base_url <- "https://d37ci6vzurychx.cloudfront.net/trip-data"
  discovered <- list(); results <- list()
  for (requested_period in periods) {
    existing <- dplyr::filter(known, .data$period == .env$requested_period)
    if (nrow(existing)) { results[[length(results) + 1L]] <- download_manifest_row(existing[1, ], raw_dir); next }
    file <- paste0("yellow_tripdata_", requested_period, ".parquet")
    row <- data.frame(file = file, period = requested_period, bytes = NA_real_, sha256 = NA_character_, source_url = paste0(base_url, "/", file))
    tmp <- paste0(file.path(raw_dir, file), ".download")
    ok <- tryCatch({ utils::download.file(row$source_url, tmp, mode = "wb", quiet = TRUE); TRUE }, error = function(e) FALSE)
    if (!ok || !file.exists(tmp)) { results[[length(results) + 1L]] <- data.frame(period = requested_period, status = "not_published_or_download_failed", file = file); next }
    row$bytes <- file.info(tmp)$size
    row$sha256 <- sha256_file(tmp)
    file.rename(tmp, file.path(raw_dir, file))
    row$discovered_utc <- format(Sys.time(), tz = "UTC", usetz = TRUE)
    discovered[[length(discovered) + 1L]] <- row
    results[[length(results) + 1L]] <- data.frame(period = requested_period, status = "downloaded_and_locally_hashed", file = file)
  }
  if (length(discovered)) {
    path <- runtime_manifest_path(raw_dir)
    all_discovered <- if (file.exists(path)) dplyr::bind_rows(readr::read_csv(path, show_col_types = FALSE), dplyr::bind_rows(discovered)) else dplyr::bind_rows(discovered)
    write_csv(dplyr::arrange(dplyr::distinct(all_discovered, period, .keep_all = TRUE), period), path)
  }
  dplyr::bind_rows(results)
}

validate_raw_manifest <- function(raw_dir = raw_data_dir()) {
  manifest <- read_raw_manifest(raw_dir)
  result <- dplyr::mutate(manifest, local_path = file.path(raw_dir, file), exists = file.exists(local_path), local_bytes = ifelse(exists, file.info(local_path)$size, NA_real_))
  result$sha256_match <- vapply(seq_len(nrow(result)), function(i) result$exists[i] && result$local_bytes[i] == result$bytes[i] && identical(tolower(sha256_file(result$local_path[i])), tolower(result$sha256[i])), logical(1))
  if (!all(result$sha256_match)) stop("Hay Parquet ausentes o inválidos; ejecute download_nyc_tlc_data().", call. = FALSE)
  result
}
