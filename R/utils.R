project_root <- function(start = getwd()) {
  path <- normalizePath(start, mustWork = TRUE)
  repeat {
    if (file.exists(file.path(path, "DESCRIPTION"))) return(path)
    parent <- dirname(path)
    if (identical(path, parent)) stop("No se encontró la raíz del paquete.", call. = FALSE)
    path <- parent
  }
}

raw_data_dir <- function(root = project_root()) file.path(root, "data", "raw", "nyc_tlc_yellow_2019_2024")
artifact_dir <- function() Sys.getenv("NYC_TAXI_ARTIFACTS", unset = file.path(project_root(), "artifacts"))
sha256_file <- function(path) digest::digest(file = path, algo = "sha256", serialize = FALSE)
write_csv <- function(x, path) { dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE); readr::write_csv(x, path, na = "") }
