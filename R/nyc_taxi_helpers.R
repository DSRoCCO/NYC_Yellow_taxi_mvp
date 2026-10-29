project_root <- function(start = getwd()) {
  candidate <- normalizePath(start, mustWork = TRUE)
  repeat {
    if (file.exists(file.path(candidate, "renv", "activate.R"))) return(candidate)
    parent <- dirname(candidate)
    if (identical(parent, candidate)) stop("No se encontró la raíz del proyecto.")
    candidate <- parent
  }
}

sql_path <- function(path) gsub("'", "''", normalizePath(path, mustWork = FALSE), fixed = TRUE)

raw_dir <- function(root = project_root()) file.path(root, "data", "raw", "nyc_tlc_yellow_2019_2024")

assert_raw_inputs <- function(root = project_root()) {
  data_dir <- raw_dir(root)
  if (!file.exists(file.path(data_dir, "manifest.csv"))) stop("Falta manifest.csv.")
  manifest <- readr::read_csv(file.path(data_dir, "manifest.csv"), show_col_types = FALSE)
  discovered <- file.path(data_dir, "manifest_discovered.csv")
  if (file.exists(discovered)) manifest <- dplyr::bind_rows(manifest, readr::read_csv(discovered, show_col_types = FALSE))
  manifest <- dplyr::distinct(manifest, period, .keep_all = TRUE)
  files <- file.path(data_dir, manifest$file)
  if (!all(file.exists(files))) stop("Faltan Parquet Yellow Taxi declarados en el manifiesto combinado.")
  invisible(sort(files))
}

write_csv_utf8 <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(x, path, na = "")
}

# Calcula SHA-256 de un archivo. Usa sha256sum del sistema o el paquete openssl.
# Devuelve el hash en minúsculas o NA_character_ si ninguna opción está disponible.
file_sha256 <- function(path) {
  if (!file.exists(path)) return(NA_character_)
  if (nzchar(Sys.which("sha256sum"))) {
    out <- tryCatch(
      system2("sha256sum", shQuote(path), stdout = TRUE, stderr = FALSE),
      error = function(e) character(0)
    )
    if (length(out) > 0L) return(trimws(strsplit(out[[1L]], "\\s+")[[1L]][[1L]]))
  }
  tryCatch(
    as.character(openssl::sha256(file(path, "rb"))),
    error = function(e) NA_character_
  )
}
