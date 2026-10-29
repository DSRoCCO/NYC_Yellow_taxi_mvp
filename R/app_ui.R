app_ui <- function() {
  bslib::page_navbar(title = "NYC Yellow Taxi — MVP", theme = app_theme(),
    bslib::nav_panel("Análisis descriptivo", mod_diagnostic_ui("diagnostic")),
    bslib::nav_panel("Validación predictiva", mod_forecast_ui("forecast")),
    bslib::nav_panel("Pronóstico de corto plazo desde el último registro oficial", mod_predictive_ui("predictive")),
    bslib::nav_panel("Proyección estacional de largo plazo", mod_scenario_ui("scenario")),
    footer = htmltools::tags$footer(class = "p-3 text-muted", "Fuente: NYC TLC Yellow Taxi. Análisis descriptivo: 2019–2024. Validación predictiva y proyección: 2022–2024.")
  )
}
