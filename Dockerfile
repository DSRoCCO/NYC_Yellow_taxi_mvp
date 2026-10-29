FROM rocker/r-ver:4.3.3
RUN apt-get update && apt-get install -y --no-install-recommends build-essential cmake curl libcurl4-openssl-dev libicu-dev libssl-dev libuv1-dev libx11-dev libxml2-dev pandoc zlib1g-dev && rm -rf /var/lib/apt/lists/*
WORKDIR /opt/nyc-yellow-taxi
COPY renv.lock renv.lock
COPY renv/activate.R renv/activate.R
COPY DESCRIPTION NAMESPACE LICENSE ./
COPY R R
RUN R -e "install.packages('renv', repos='https://cloud.r-project.org'); renv::restore(packages=c('bslib','DT','digest','dplyr','ggplot2','golem','htmltools','lubridate','readr','scales','shiny'), prompt=FALSE)" && R CMD INSTALL .
RUN useradd --create-home --uid 10001 appuser && mkdir -p /opt/artifacts && chown appuser:appuser /opt/artifacts
USER appuser
ENV NYC_TAXI_ARTIFACTS=/opt/artifacts
EXPOSE 3838
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s CMD curl -fsS http://localhost:3838/ || exit 1
CMD ["R", "-e", "nycyellowtaximvp::run_app(host='0.0.0.0', port=3838)"]
