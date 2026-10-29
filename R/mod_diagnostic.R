mod_diagnostic_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::layout_columns(
    bslib::value_box(title = "Cobertura", value = shiny::textOutput(ns("coverage"))),
    bslib::value_box(title = "Viajes validados", value = shiny::textOutput(ns("trips"))),
    bslib::value_box(title = "Anomalías temporales", value = shiny::textOutput(ns("anomalies"))),
    col_widths = c(4, 4, 4),
    bslib::card(bslib::card_header("Demanda mensual por régimen"), shiny::plotOutput(ns("monthly"), height = 300)),
    bslib::card(bslib::card_header("Zonas líderes por régimen"), shiny::tableOutput(ns("zones"))),
    bslib::card(bslib::card_header("Zonas válidas usadas en el análisis"), DT::DTOutput(ns("valid_zones"))),
    bslib::card(bslib::card_header("Límites de interpretación"), shiny::uiOutput(ns("limits")))
  )
}
mod_diagnostic_server <- function(id, artifacts) {
  shiny::moduleServer(id, function(input, output, session) {
    ev <- artifacts$app$evidence; quality <- ev$data_quality_by_source_month; monthly <- ev$monthly_city_profile
    output$coverage <- shiny::renderText("2019-01 a 2024-12")
    output$trips <- shiny::renderText(format(sum(quality$trips), big.mark = ","))
    output$anomalies <- shiny::renderText(format(sum(quality$timestamp_outside_source_period), big.mark = ","))
    output$monthly <- shiny::renderPlot({ ggplot2::ggplot(monthly, ggplot2::aes(as.Date(month), trips, colour = regime)) + ggplot2::geom_line() + ggplot2::scale_y_continuous(labels = scales::label_number(scale_cut = scales::cut_short_scale())) + ggplot2::labs(x = NULL, y = "Viajes", colour = "Régimen") + ggplot2::theme_minimal() })
    output$zones <- shiny::renderTable({ dplyr::arrange(dplyr::group_by(ev$zone_regime_profile, regime), dplyr::desc(trips), .by_group = TRUE) |> dplyr::slice_head(n = 3) |> dplyr::select(regime, Zone, Borough, trips) })
    output$valid_zones <- DT::renderDT(DT::datatable(artifacts$app$valid_zones, rownames = FALSE, filter = "top", options = list(pageLength = 10, lengthMenu = c(10, 25, 50), scrollX = TRUE), colnames = c("ID", "Distrito", "Zona", "Área de servicio")))
    output$limits <- shiny::renderUI(htmltools::tags$ul(htmltools::tags$li("Los cambios entre regímenes son descriptivos, no causales."), htmltools::tags$li("Los viajes registrados no miden oferta ni demanda no atendida."), htmltools::tags$li("Cobertura cerrada en diciembre de 2024.")))
  })
}
