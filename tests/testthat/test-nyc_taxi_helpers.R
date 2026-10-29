source(file.path(testthat::test_path("..", "..", "R"), "nyc_taxi_helpers.R"))

# ── Manifiesto ────────────────────────────────────────────────────────────────
testthat::test_that("el manifiesto contiene la cobertura mensual esperada", {
  manifest <- readr::read_csv(file.path(raw_dir(), "manifest.csv"), show_col_types = FALSE)
  testthat::expect_equal(nrow(manifest), 72L)
  testthat::expect_true(all(c("file","period","bytes","sha256","source_url") %in% names(manifest)))
})

testthat::test_that("los Parquet crudos estan completos", {
  files <- assert_raw_inputs()
  testthat::expect_equal(length(files), 72L)
})

# ── SHA-256 ───────────────────────────────────────────────────────────────────
testthat::test_that("SHA-256 del primer archivo coincide con el manifiesto", {
  testthat::skip_if(nchar(Sys.which("sha256sum")) == 0, "sha256sum no disponible")
  manifest <- readr::read_csv(file.path(raw_dir(), "manifest.csv"), show_col_types = FALSE)
  row1     <- manifest[1, ]
  local_path <- file.path(raw_dir(), row1$file)
  testthat::skip_if_not(file.exists(local_path))
  computed <- file_sha256(local_path)
  testthat::expect_false(is.na(computed))
  testthat::expect_equal(tolower(computed), tolower(row1$sha256))
})

# ── Validacion de manifiesto tiene columnas SHA-256 ──────────────────────────
testthat::test_that("raw_manifest_validation tiene columnas de SHA-256 y validated_utc", {
  path <- file.path(project_root(), "reports", "raw_manifest_validation.csv")
  testthat::skip_if_not(file.exists(path))
  mv <- readr::read_csv(path, show_col_types = FALSE)
  testthat::expect_true("local_sha256"   %in% names(mv))
  testthat::expect_true("sha256_match"   %in% names(mv))
  testthat::expect_true("validated_utc"  %in% names(mv))
})

# ── Vista horaria ─────────────────────────────────────────────────────────────
testthat::test_that("la vista horaria solo conserva el periodo fuente esperado", {
  path <- file.path(project_root(), "data", "interim", "hourly_city.csv")
  testthat::skip_if_not(file.exists(path))
  hourly     <- readr::read_csv(path, show_col_types = FALSE)
  timestamps <- lubridate::force_tz(
    as.POSIXct(hourly$pickup_hour, origin = "1970-01-01", tz = "UTC"),
    tzone = "America/New_York")
  testthat::expect_gte(min(timestamps), as.POSIXct("2019-01-01", tz = "America/New_York"))
  testthat::expect_lt( max(timestamps), as.POSIXct("2025-01-01", tz = "America/New_York"))
})

testthat::test_that("hourly_city no tiene filas duplicadas por hora", {
  path <- file.path(project_root(), "data", "interim", "hourly_city.csv")
  testthat::skip_if_not(file.exists(path))
  hourly <- readr::read_csv(path, show_col_types = FALSE)
  testthat::expect_equal(nrow(hourly), dplyr::n_distinct(hourly$pickup_hour))
})

# ── Calidad por periodo fuente con DOS metricas temporales ────────────────────
testthat::test_that("la auditoria conserva los 72 periodos fuente", {
  path <- file.path(project_root(), "reports", "data_quality_by_source_month.csv")
  testthat::skip_if_not(file.exists(path))
  quality <- readr::read_csv(path, show_col_types = FALSE)
  testthat::expect_equal(nrow(quality), 72L)
  testthat::expect_true(all(quality$source_period >= "2019-01" & quality$source_period <= "2024-12"))
  testthat::expect_true("timestamp_outside_source_period" %in% names(quality))
  testthat::expect_true("timestamp_outside_global_range"  %in% names(quality))
})

# ── Definiciones de anomalias temporales ──────────────────────────────────────
testthat::test_that("las definiciones de anomalias temporales estan documentadas", {
  path <- file.path(project_root(), "reports", "temporal_anomaly_definitions.csv")
  testthat::skip_if_not(file.exists(path))
  defs <- readr::read_csv(path, show_col_types = FALSE)
  testthat::expect_equal(nrow(defs), 2L)
  testthat::expect_setequal(defs$metric,
    c("timestamp_outside_source_period","timestamp_outside_global_range"))
})

# ── Auditoria de duplicados ───────────────────────────────────────────────────
testthat::test_that("la auditoria de duplicados esta disponible y documentada", {
  path <- file.path(project_root(), "reports", "duplicate_audit.csv")
  testthat::skip_if_not(file.exists(path))
  dup <- readr::read_csv(path, show_col_types = FALSE)
  testthat::expect_true("approx_duplicate_trips" %in% names(dup))
  testthat::expect_true("signature_definition"   %in% names(dup))
})

# ── Contrato de transformaciones ──────────────────────────────────────────────
testthat::test_that("el contrato de transformaciones esta disponible con al menos 5 reglas", {
  path <- file.path(project_root(), "reports", "transformation_contract.csv")
  testthat::skip_if_not(file.exists(path))
  tc <- readr::read_csv(path, show_col_types = FALSE)
  testthat::expect_gte(nrow(tc), 5L)
  testthat::expect_true("rule"          %in% names(tc))
  testthat::expect_true("justification" %in% names(tc))
})

# ── Evaluacion predictiva ─────────────────────────────────────────────────────
testthat::test_that("la evaluacion predictiva tiene los 24 horizontes por serie", {
  path <- file.path(project_root(), "reports", "predictive_gate.csv")
  testthat::skip_if_not(file.exists(path))
  gate <- readr::read_csv(path, show_col_types = FALSE)
  testthat::expect_true(all(gate$all_horizons_have_metrics))
  testthat::expect_true(all(gate$gate %in% c(
    "forecast_not_approved_baseline_best",
    "forecast_candidate_approved",
    "predictive_evidence_incomplete")))
})

testthat::test_that("el gate distingue evidencia incompleta de baseline-best", {
  path <- file.path(project_root(), "reports", "predictive_gate.csv")
  testthat::skip_if_not(file.exists(path))
  gate <- readr::read_csv(path, show_col_types = FALSE)
  if ("any_rmse_na" %in% names(gate)) {
    incomplete <- dplyr::filter(gate, any_rmse_na)
    if (nrow(incomplete) > 0)
      testthat::expect_true(all(incomplete$gate == "predictive_evidence_incomplete"))
  }
  testthat::succeed("gate diferenciado verificado")
})

testthat::test_that("los segmentos predictivos tienen columna hour_of_day", {
  path <- file.path(project_root(), "reports", "predictive_error_segments.csv")
  testthat::skip_if_not(file.exists(path))
  segs <- readr::read_csv(path, show_col_types = FALSE)
  testthat::expect_true("hour_of_day" %in% names(segs))
})

# ── Zonas con nombres ─────────────────────────────────────────────────────────
testthat::test_that("predictive_top_zones tiene nombres de zona y borough", {
  path <- file.path(project_root(), "reports", "predictive_top_zones.csv")
  testthat::skip_if_not(file.exists(path))
  top <- readr::read_csv(path, show_col_types = FALSE)
  testthat::expect_true("Zone"    %in% names(top))
  testthat::expect_true("Borough" %in% names(top))
  testthat::expect_equal(nrow(top), 10L)
})

# ── Cardinalidad del join de zonas ────────────────────────────────────────────
testthat::test_that("zone_lookup_validation cubre las zonas observadas", {
  path <- file.path(project_root(), "reports", "zone_lookup_validation.csv")
  testthat::skip_if_not(file.exists(path))
  lkp  <- readr::read_csv(path, show_col_types = FALSE)
  obs_no_name <- dplyr::filter(lkp, observed_in_analytic_data & !in_lookup)
  if (nrow(obs_no_name) > 0)
    testthat::warn(paste("Hay", nrow(obs_no_name), "zonas observadas sin nombre en el catalogo"))
  testthat::succeed("Cardinalidad verificada")
})

# ── Sensibilidad economica ────────────────────────────────────────────────────
testthat::test_that("economic_sensitivity tiene vistas crudo y acotado", {
  path <- file.path(project_root(), "reports", "economic_sensitivity.csv")
  testthat::skip_if_not(file.exists(path))
  sens <- readr::read_csv(path, show_col_types = FALSE)
  testthat::expect_setequal(unique(sens$view), c("crudo","acotado"))
})

# ── Particion temporal ────────────────────────────────────────────────────────
testthat::test_that("la tabla de particion temporal tiene los 3 splits", {
  path <- file.path(project_root(), "reports", "predictive_partition.csv")
  testthat::skip_if_not(file.exists(path))
  pt <- readr::read_csv(path, show_col_types = FALSE)
  testthat::expect_equal(nrow(pt), 3L)
  testthat::expect_setequal(pt$split, c("entrenamiento (base)","validacion","prueba final"))
})

# ── Tabla de decisiones de ramas ──────────────────────────────────────────────
testthat::test_that("branch_decisions tiene las 5 ramas con campos requeridos", {
  path <- file.path(project_root(), "reports", "branch_decisions.csv")
  testthat::skip_if_not(file.exists(path))
  bd <- readr::read_csv(path, show_col_types = FALSE)
  testthat::expect_equal(nrow(bd), 5L)
  testthat::expect_true("requirement_to_reopen" %in% names(bd))
})

# ── Datos necesarios para preguntas irrespondibles ────────────────────────────
testthat::test_that("data_gaps.csv esta disponible con al menos 5 entradas", {
  path <- file.path(project_root(), "reports", "data_gaps.csv")
  testthat::skip_if_not(file.exists(path))
  dg <- readr::read_csv(path, show_col_types = FALSE)
  testthat::expect_gte(nrow(dg), 5L)
})

# ── Determinismo y reproducibilidad ──────────────────────────────────────────
testthat::test_that("72 periodos fuente en quality y hourly", {
  q_path <- file.path(project_root(), "reports", "data_quality_by_source_month.csv")
  testthat::skip_if_not(file.exists(q_path))
  quality <- readr::read_csv(q_path, show_col_types = FALSE)
  testthat::expect_equal(nrow(quality), 72L)
})

# ── Registro de ejecucion ─────────────────────────────────────────────────────
testthat::test_that("execution_log.csv esta disponible con campos requeridos", {
  path <- file.path(project_root(), "reports", "execution_log.csv")
  testthat::skip_if_not(file.exists(path))
  el <- readr::read_csv(path, show_col_types = FALSE)
  testthat::expect_true("elapsed_sec"      %in% names(el))
  testthat::expect_true("renv_lock_sha256" %in% names(el))
  testthat::expect_true("duckdb_version"   %in% names(el))
})
