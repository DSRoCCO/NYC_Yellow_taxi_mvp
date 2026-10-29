# NYC Yellow Taxi MVP

Proyecto de portafolio para estudiar los viajes de **Yellow Taxi de Nueva York** publicados por la NYC Taxi & Limousine Commission (TLC). El alcance actual es el análisis integral reproducible en R; no se construye aún una aplicación ni un MVP operativo.

## Datos

La fuente cruda corresponde a los archivos mensuales oficiales Yellow Taxi de enero de 2019 a diciembre de 2024. Los archivos Parquet no se versionan en Git. El repositorio conserva:

- `data/raw/nyc_tlc_yellow_2019_2024/manifest.csv`: URLs oficiales, período, tamaño y SHA-256 de los 72 archivos.
- `data/raw/nyc_tlc_yellow_2019_2024/taxi_zone_lookup.csv`: catálogo oficial de zonas.
- `data/raw/nyc_tlc_yellow_2019_2024/README.md`: procedencia y reglas de inmutabilidad.

Los datos deben descargarse localmente en la misma carpeta, validarse contra el manifiesto y mantenerse fuera de Git. La descarga reproducible se incorporará antes de ejecutar el análisis completo.

## Alcance analítico

El cuaderno único `notebooks/analisis_integral_nyc_yellow_taxi.qmd` documenta calidad, preparación, análisis descriptivo y diagnóstico, exploración abierta, evaluación predictiva y límites prescriptivos sin inferir causalidad. Renderiza a partir de la evidencia congelada en `reports/`; no requiere una carpeta `scripts/` ni datos intermedios.

El proyecto previo se conserva sin cambios funcionales en `proyecto anterior/` como referencia histórica y no forma parte de este análisis.

## Entorno

R y sus dependencias se administran con `renv`. El cuaderno se renderiza directamente con Quarto; no requiere configuración de kernel de Jupyter.

