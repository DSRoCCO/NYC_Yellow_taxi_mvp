# NYC Yellow Taxi — análisis y proyecciones

Proyecto de portafolio en R/Shiny sobre los viajes Yellow Taxi publicados por la NYC Taxi & Limousine Commission (TLC). Convierte un análisis integral reproducible en un MVP interactivo, sin versionar los Parquet ni los artefactos derivados.

## Qué incluye

- **Análisis descriptivo:** cobertura, calidad, estacionalidad, concentración geográfica y zonas TLC usadas.
- **Validación predictiva:** backtesting de `lag_calendar` para ciudad y diez zonas, evaluado sólo en 2022–2024.
- **Pronóstico de corto plazo desde el último registro oficial:** 1–168 horas después del corte real del bundle.
- **Proyección estacional de largo plazo:** cono de incertidumbre de 7 a 730 días; es un escenario basado en patrones históricos, no una previsión operativa vigente.

La evidencia integral está disponible en dos formatos:

- [Código Quarto del análisis](notebooks/analisis_integral_nyc_yellow_taxi.qmd)
- [PDF del análisis](notebooks/analisis_integral_nyc_yellow_taxi.pdf)

## Alcance y límites

El análisis descriptivo usa todos los Parquet locales desde 2019 hasta el último mes oficial descargado. La validación predictiva congelada corresponde a 2022–2024; incorporar meses nuevos al bundle mueve el corte del pronóstico corto, pero no reemplaza esa evaluación histórica sin una nueva validación formal.

Los modelos usan demanda pasada y calendario. No incorporan clima, vuelos, demoras aeroportuarias, eventos, tráfico, obras, transporte público, tarifas, peajes, oferta de taxis/conductores, turismo, economía o regulación. No establecen causalidad ni deben utilizarse para fijar precios, incentivos, flota o decisiones automáticas.

## Requisitos

- Git.
- R 4.3.x.
- Quarto para renderizar el análisis y publicar GitHub Pages.
- Docker, opcional, para el MVP contenido.
- Al menos 8 GB libres para los Parquet, el bundle y temporales.

## Inicio rápido desde un clon limpio

```bash
git clone https://github.com/DSRoCCO/NYC_Yellow_taxi_mvp.git
cd nyc_yellow_taxi_mvp
Rscript -e 'renv::restore(prompt = FALSE)'
R CMD INSTALL .
```

### Descargar y validar datos TLC

La fuente es [NYC TLC Trip Record Data](https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page). Los archivos crudos se almacenan localmente en `data/raw/nyc_tlc_yellow_2019_2024/` y nunca se suben a Git ni se copian a Docker.

```bash
# Manifiesto congelado: 2019–2024, con tamaño y SHA-256 versionados.
Rscript exec/download_data.R

# Meses publicados después de 2024: descubre URL oficial, descarga y registra
# localmente tamaño, SHA-256 y fecha de descubrimiento.
Rscript exec/update_latest_data.R
```

`update_latest_data.R` no reemplaza archivos ya validados. Su registro local `manifest_discovered.csv` está ignorado por Git. Para descargar períodos concretos del manifiesto congelado:

```r
nycyellowtaximvp::download_nyc_tlc_data(periods = c("2024-11", "2024-12"))
```

### Generar el bundle y ejecutar la app

```bash
Rscript exec/build_artifacts.R
Rscript -e 'nycyellowtaximvp::run_app(host = "127.0.0.1", port = 4202)'
```

Abra `http://127.0.0.1:4202`. El bundle local en `artifacts/` contiene agregados, modelos y metadatos; no contiene los Parquet completos.

## Análisis Quarto

Con todos los Parquet locales, el QMD calcula la actualización descriptiva hasta el último mes descargado:

```bash
quarto render notebooks/analisis_integral_nyc_yellow_taxi.qmd
quarto render notebooks/analisis_integral_nyc_yellow_taxi.qmd --to pdf
```

Sin Parquet —por ejemplo, en GitHub Pages— el documento renderiza la evidencia congelada 2019–2024 y lo declara dentro del informe.

## Pruebas

```bash
Rscript -e 'testthat::test_local(reporter = "summary")'
Rscript -e 'renv::status()'
```

## Docker

La imagen sólo contiene el paquete y dependencias bloqueadas. No incluye Parquet, `artifacts/`, reportes, notebooks, HTML, PDF ni secretos. El bundle debe montarse como volumen de solo lectura.

```bash
docker build -t nyc-yellow-taxi-mvp .
docker run --rm \
  --mount type=bind,src="$(pwd)/artifacts",dst=/opt/artifacts,readonly \
  -p 127.0.0.1:3838:3838 \
  nyc-yellow-taxi-mvp
```

Abra `http://127.0.0.1:3838`. El proceso se ejecuta como usuario no root y expone un healthcheck HTTP. Primero genere `artifacts/`; sin ese volumen la app se detiene deliberadamente porque no tiene un contrato de datos válido.

## GitHub Pages

El workflow [publish-analysis.yml](.github/workflows/publish-analysis.yml) renderiza y publica la evidencia estática al hacer push a `main` o mediante `workflow_dispatch`. No publica la app Shiny, Parquet, bundles ni datos privados/locales.

Después del primer push, habilite **Settings → Pages → Build and deployment → Source: GitHub Actions** en el repositorio. La URL resultante será:

```text
https://dsrocco.github.io/NYC_Yellow_taxi_mvp/
```

## Estructura relevante

```text
R/                  Lógica del paquete, pipeline y módulos Shiny.
exec/               Comandos reproducibles de descarga y construcción.
notebooks/          QMD y PDF de la evidencia integral.
reports/            Evidencia congelada y métricas agregadas.
data/raw/           Datos TLC locales, excluidos de Git.
artifacts/          Bundle local para la app, excluido de Git.
.github/workflows/  Publicación estática a GitHub Pages.
```

Consulte [project_spec.md](project_spec.md) para el contrato entre evidencia, bundle y MVP.
