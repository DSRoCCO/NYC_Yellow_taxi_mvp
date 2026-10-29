# Procedencia de datos

- Fuente: NYC TLC Yellow Taxi Trip Records.
- Licencia: dominio publico (NYC Open Data).
- Zona horaria: timestamps en hora local de Nueva York (Eastern Time); sin zona horaria explicita.
- Cobertura: 2019-01 a 2024-12.
- Fecha de extraccion: ver campo validated_utc en raw_manifest_validation.csv.
- Los Parquet crudos son inmutables; los derivados se generaron con scripts/build_foundation.R.
- Las vistas temporales analiticas conservan solo timestamps cuyo mes coincide con el periodo declarado.
- Las dos anomalias temporales se documentan en temporal_anomaly_definitions.csv.
- Archivos validados por bytes: 72; SHA-256 calculado: TRUE.
- Ejecucion UTC: 2026-10-29 16:48:31 UTC.
- R: R version 4.3.3 (2024-02-29).
- DuckDB: 2.0.0.
