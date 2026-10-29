app_server <- function(input, output, session) {
  artifacts <- tryCatch(load_artifacts(), error = function(e) e)
  if (inherits(artifacts, "error")) { shiny::showNotification(conditionMessage(artifacts), type = "error", duration = NULL); return() }
  mod_diagnostic_server("diagnostic", artifacts)
  mod_forecast_server("forecast", artifacts)
  mod_predictive_server("predictive", artifacts)
  mod_scenario_server("scenario", artifacts)
}
