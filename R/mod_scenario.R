mod_scenario_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::layout_sidebar(
    sidebar = bslib::sidebar(
      shiny::selectInput(ns("series"), "Serie", choices = c("Ciudad de Nueva York" = "city")),
      shiny::dateInput(ns("start_date"), "Inicio del escenario", value = NULL),
      shiny::selectInput(ns("horizon_days"), "Rango futuro", choices = c("7 días" = 7, "30 días" = 30, "90 días" = 90, "180 días" = 180, "365 días" = 365, "730 días" = 730), selected = 30),
      shiny::actionButton(ns("reset"), "Restablecer escenario", class = "btn-outline-secondary")
    ),
    bslib::card(bslib::card_header("Cono de incertidumbre de la proyección estacional"), shiny::plotOutput(ns("cone"), height = 380)),
    bslib::card(bslib::card_header("Resumen del escenario"), shiny::tableOutput(ns("scenario"))),
    bslib::card(bslib::card_header("Supuestos y advertencias"), shiny::uiOutput(ns("note")))
  )
}

mod_scenario_server <- function(id, artifacts) {
  shiny::moduleServer(id, function(input, output, session) {
    labels <- stats::setNames(c("city", paste0("zone_", artifacts$forecast$zones$pickup_zone)), c("Ciudad de Nueva York", paste0(artifacts$forecast$zones$Zone, " (", artifacts$forecast$zones$Borough, ")")))
    cutoff <- tail(artifacts$forecast$series$city$epoch, 1L)
    min_date <- as.Date(as.POSIXct(cutoff + 3600, origin = "1970-01-01", tz = "UTC"))
    set_date_bounds <- function(days) {
      max_date <- as.Date(as.POSIXct(cutoff + (730L - days) * 24L * 3600L, origin = "1970-01-01", tz = "UTC"))
      shiny::updateDateInput(session, "start_date", min = min_date, max = max_date)
    }
    shiny::updateSelectInput(session, "series", choices = labels, selected = "city")
    shiny::updateDateInput(session, "start_date", value = min_date, min = min_date)
    set_date_bounds(30L)
    shiny::observeEvent(input$horizon_days, set_date_bounds(as.integer(input$horizon_days)), ignoreInit = TRUE)
    shiny::observeEvent(input$reset, { shiny::updateSelectInput(session, "series", selected = "city"); shiny::updateDateInput(session, "start_date", value = min_date); shiny::updateSelectInput(session, "horizon_days", selected = "30") })
    start_epoch <- shiny::reactive({ shiny::req(input$start_date); as.numeric(as.POSIXct(sprintf("%s 00:00", input$start_date), tz = "UTC")) })
    result <- shiny::reactive({ tryCatch(seasonal_scenario_range(artifacts$forecast, input$series, start_epoch(), as.integer(input$horizon_days)), error = function(e) shiny::validate(shiny::need(FALSE, conditionMessage(e)))) })
    output$cone <- shiny::renderPlot({
      d <- result()
      ggplot2::ggplot(d, ggplot2::aes(period, prediction)) +
        ggplot2::geom_ribbon(ggplot2::aes(ymin = lower_95, ymax = upper_95), fill = "#4C78A8", alpha = 0.15) +
        ggplot2::geom_ribbon(ggplot2::aes(ymin = lower_80, ymax = upper_80), fill = "#4C78A8", alpha = 0.30) +
        ggplot2::geom_line(colour = "#007C91", linewidth = 0.8) +
        ggplot2::labs(x = NULL, y = if (as.integer(input$horizon_days) <= 90L) "Viajes estimados por día" else "Viajes estimados por semana", caption = "Banda oscura: 80%. Banda clara: 95%. Intervalos agregados aproximados.") +
        ggplot2::theme_minimal()
    })
    output$scenario <- shiny::renderTable({ d <- result(); data.frame(serie = names(labels)[match(input$series, labels)], inicio = format(min(d$period), "%Y-%m-%d"), fin = format(max(d$period), "%Y-%m-%d"), granularidad = if (as.integer(input$horizon_days) <= 90L) "Diaria" else "Semanal", total_base = round(sum(d$prediction)), rango_total_80 = sprintf("%s – %s", round(sum(d$lower_80)), round(sum(d$upper_80))), rango_total_95 = sprintf("%s – %s", round(sum(d$lower_95)), round(sum(d$upper_95)))) })
    output$note <- shiny::renderUI(htmltools::tagList(
      htmltools::tags$p("Escenario basado en patrones históricos; no usa observaciones recientes ni representa una previsión operativa vigente.", class = "fw-semibold"),
      htmltools::tags$p("Usa únicamente hora, día de la semana y mes aprendidos desde 2022. El cono suma bandas horarias residuales, por lo que los rangos agregados son aproximados y no incorporan cambios estructurales posteriores."),
      htmltools::tags$p("No incorpora clima, vuelos, eventos, tráfico, oferta, tarifas, turismo, economía, regulación ni información posterior al último corte. No usar para decisiones automáticas o causales.", class = "text-muted")
    ))
  })
}
