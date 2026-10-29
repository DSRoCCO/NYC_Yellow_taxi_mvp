load_artifacts <- function(path = artifact_dir()) {
  required <- file.path(path, c("app_data.rds", "forecast_bundle.rds", "artifact_manifest.csv"))
  if (!all(file.exists(required))) stop("Faltan artefactos. Ejecute build_artifact_bundle() y configure NYC_TAXI_ARTIFACTS.", call. = FALSE)
  app <- readRDS(required[1]); forecast <- readRDS(required[2]); manifest <- readr::read_csv(required[3], show_col_types = FALSE)
  if (!identical(app$schema_version, "1.3") || !identical(forecast$schema_version, "1.3")) stop("Versión de artefactos incompatible; actualice datos oficiales y regenere el bundle.", call. = FALSE)
  list(app = app, forecast = forecast, manifest = manifest)
}

forecast_historical <- function(bundle, series_id, origin, horizon) {
  if (!is.character(series_id) || length(series_id) != 1L || is.na(series_id) || is.null(bundle$series[[series_id]])) stop("La serie seleccionada no está disponible en el bundle.", call. = FALSE)
  series_id <- trimws(unname(as.character(series_id[[1L]])))
  if (length(origin) != 1L || is.na(origin) || !is.finite(origin)) stop("Seleccione un origen histórico válido.", call. = FALSE)
  if (length(horizon) != 1L || is.na(horizon) || !is.finite(horizon) || horizon < 1L || horizon > 24L) stop("El horizonte debe estar entre 1 y 24 horas.", call. = FALSE)
  horizon <- as.integer(horizon)
  x <- bundle$series[[series_id]]; model <- bundle$models[[series_id]]; pos <- match(as.numeric(origin), x$epoch)
  if (length(pos) != 1L || is.na(pos) || pos < 168L || pos + horizon > nrow(x)) stop("Origen u horizonte fuera de la cobertura histórica.", call. = FALSE)
  values <- x$trips; pred <- numeric(horizon)
  for (h in seq_len(horizon)) { j <- pos + h; f <- calendar_frame(x$epoch[j]); f$l1 <- log1p(values[j - 1]); f$l24 <- log1p(values[j - 24]); f$l168 <- log1p(values[j - 168]); pred[h] <- max(0, exp(stats::predict(model, f)) - 1); values[j] <- pred[h] }
  data.frame(epoch = x$epoch[(pos + 1):(pos + horizon)], prediction = pred, observed = x$trips[(pos + 1):(pos + horizon)])
}

forecast_future <- function(bundle, series_id, horizon) {
  if (!is.character(series_id) || length(series_id) != 1L || is.na(series_id) || is.null(bundle$series[[series_id]])) stop("La serie seleccionada no está disponible en el bundle.", call. = FALSE)
  if (length(horizon) != 1L || is.na(horizon) || !is.finite(horizon) || horizon < 1L || horizon > 168L) stop("El horizonte debe estar entre 1 y 168 horas.", call. = FALSE)
  horizon <- as.integer(horizon)
  x <- bundle$series[[series_id]]
  model <- bundle$models[[series_id]]
  values <- x$trips
  epochs <- tail(x$epoch, 1L) + seq_len(horizon) * 3600
  prediction <- lower <- upper <- numeric(horizon)

  for (h in seq_len(horizon)) {
    j <- length(values) + 1L
    f <- calendar_frame(epochs[h])
    f$l1 <- log1p(values[j - 1L])
    f$l24 <- log1p(values[j - 24L])
    f$l168 <- log1p(values[j - 168L])
    estimate <- stats::predict(model, f, se.fit = TRUE)
    predictive_sd <- sqrt(estimate$se.fit^2 + estimate$residual.scale^2)
    prediction[h] <- max(0, exp(estimate$fit) - 1)
    lower[h] <- max(0, exp(estimate$fit - 1.96 * predictive_sd) - 1)
    upper[h] <- exp(estimate$fit + 1.96 * predictive_sd) - 1
    values <- c(values, prediction[h])
  }
  data.frame(epoch = epochs, prediction = prediction, lower = lower, upper = upper)
}

seasonal_scenario <- function(bundle, series_id, target_epoch) {
  if (!is.character(series_id) || length(series_id) != 1L || is.na(series_id) || is.null(bundle$seasonal_models[[series_id]])) stop("La serie seleccionada no está disponible en el bundle.", call. = FALSE)
  if (length(target_epoch) != 1L || is.na(target_epoch) || !is.finite(target_epoch)) stop("Seleccione una fecha y hora futuras válidas.", call. = FALSE)
  cutoff <- tail(bundle$series[[series_id]]$epoch, 1L)
  if (target_epoch <= cutoff || target_epoch > cutoff + 730L * 24L * 3600L) stop("El escenario debe estar después del corte y dentro de los próximos 24 meses.", call. = FALSE)
  estimate <- stats::predict(bundle$seasonal_models[[series_id]], calendar_frame(target_epoch), se.fit = TRUE)
  sd_prediction <- sqrt(estimate$se.fit^2 + estimate$residual.scale^2)
  data.frame(epoch = target_epoch, prediction = max(0, exp(estimate$fit) - 1), lower_80 = max(0, exp(estimate$fit - 1.282 * sd_prediction) - 1), upper_80 = exp(estimate$fit + 1.282 * sd_prediction) - 1, lower_95 = max(0, exp(estimate$fit - 1.96 * sd_prediction) - 1), upper_95 = exp(estimate$fit + 1.96 * sd_prediction) - 1)
}

seasonal_scenario_range <- function(bundle, series_id, start_epoch, horizon_days) {
  if (length(horizon_days) != 1L || is.na(horizon_days) || !horizon_days %in% c(7L, 30L, 90L, 180L, 365L, 730L)) stop("Seleccione un horizonte entre los valores disponibles.", call. = FALSE)
  if (!is.character(series_id) || length(series_id) != 1L || is.na(series_id) || is.null(bundle$seasonal_models[[series_id]])) stop("La serie seleccionada no está disponible en el bundle.", call. = FALSE)
  cutoff <- tail(bundle$series[[series_id]]$epoch, 1L)
  if (length(start_epoch) != 1L || is.na(start_epoch) || start_epoch <= cutoff || start_epoch + as.integer(horizon_days) * 24L * 3600L > cutoff + 730L * 24L * 3600L) stop("El escenario completo debe estar después del corte y dentro de los próximos 24 meses.", call. = FALSE)
  epochs <- as.numeric(start_epoch) + seq.int(0L, as.integer(horizon_days) * 24L - 1L) * 3600
  estimate <- stats::predict(bundle$seasonal_models[[series_id]], calendar_frame(epochs), se.fit = TRUE)
  sd_prediction <- sqrt(estimate$se.fit^2 + estimate$residual.scale^2)
  hourly <- data.frame(epoch = epochs, prediction = pmax(0, exp(estimate$fit) - 1), lower_80 = pmax(0, exp(estimate$fit - 1.282 * sd_prediction) - 1), upper_80 = exp(estimate$fit + 1.282 * sd_prediction) - 1, lower_95 = pmax(0, exp(estimate$fit - 1.96 * sd_prediction) - 1), upper_95 = exp(estimate$fit + 1.96 * sd_prediction) - 1)
  hourly$time <- as.POSIXct(hourly$epoch, origin = "1970-01-01", tz = "UTC")
  hourly$period <- if (horizon_days <= 90L) as.Date(hourly$time) else as.Date(cut(hourly$time, "week", start.on.monday = TRUE))
  dplyr::summarise(dplyr::group_by(hourly, period), prediction = sum(prediction), lower_80 = sum(lower_80), upper_80 = sum(upper_80), lower_95 = sum(lower_95), upper_95 = sum(upper_95), .groups = "drop")
}
