# NYC TLC Yellow Taxi Trip Records, 2019–2024

Datos crudos oficiales de la NYC Taxi & Limousine Commission (TLC), descargados
mensualmente en formato Parquet. Cada archivo `yellow_tripdata_YYYY-MM.parquet`
corresponde a un mes calendario de viajes Yellow Taxi.

## Fuente y alcance

- Fuente: <https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page>
- Cobertura prevista: enero de 2019 a diciembre de 2024 (72 archivos).
- Formato: Parquet, preservado sin conversiones ni modificaciones.
- Catálogo de zonas: `taxi_zone_lookup.csv`, descargado desde el enlace oficial
  Taxi Zone Lookup de TLC.

## Uso y límites

Los archivos son insumos inmutables para análisis. `manifest.csv` registra nombre,
periodo, tamaño, checksum SHA-256 local y URL de origen. Los esquemas pueden variar
entre años, por lo que la normalización se realizará solo en una capa analítica
posterior y nunca sobre estos Parquet.
