mod_forecast_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::layout_sidebar(
    sidebar = bslib::sidebar(shiny::selectInput(ns("series"), "Serie", choices = c("Ciudad de Nueva York" = "city")), shiny::dateInput(ns("origin_date"), "Fecha de origen", value = NULL), shiny::selectInput(ns("origin_hour"), "Hora de origen (UTC)", choices = sprintf("%02d:00", 0:23)), shiny::sliderInput(ns("horizon"), "Horizonte (horas)", min = 1, max = 24, value = 6), shiny::actionButton(ns("reset"), "Restablecer escenario", class = "btn-outline-secondary"), htmltools::tags$hr(), htmltools::tags$p("Validación retrospectiva: entrenamiento y evaluación 2022–2024. El origen no usa datos posteriores a la hora elegida.")),
    bslib::card(bslib::card_header("Validación predictiva: estimado frente a observado"), shiny::plotOutput(ns("forecast"), height = 350)),
    bslib::card(bslib::card_header("Resultado, alcance y variables no incluidas"), shiny::tableOutput(ns("summary")), shiny::uiOutput(ns("note")))
  )
}
mod_forecast_server <- function(id, artifacts) {
  shiny::moduleServer(id, function(input, output, session) {
    ids <- names(artifacts$forecast$series)
    labels <- stats::setNames(
      c("city", paste0("zone_", artifacts$forecast$zones$pickup_zone)),
      c("Ciudad de Nueva York", paste0(artifacts$forecast$zones$Zone, " (", artifacts$forecast$zones$Borough, ")"))
    )
    shiny::updateSelectInput(session, "series", choices = labels, selected = "city")
    base_origin <- function(id) { x <- artifacts$forecast$series[[id]]; x$epoch[nrow(x) - 24L] }
    set_origin <- function(epoch) { shiny::updateDateInput(session, "origin_date", value = as.Date(as.POSIXct(epoch, origin = "1970-01-01", tz = "UTC"))); shiny::updateSelectInput(session, "origin_hour", selected = format(as.POSIXct(epoch, origin = "1970-01-01", tz = "UTC"), "%H:00")) }
    city <- artifacts$forecast$series[["city"]]
    shiny::updateDateInput(session, "origin_date", min = as.Date(as.POSIXct(city$epoch[169L], origin = "1970-01-01", tz = "UTC")), max = as.Date(as.POSIXct(base_origin("city"), origin = "1970-01-01", tz = "UTC")))
    set_origin(base_origin("city"))
    shiny::observeEvent(input$series, { shiny::req(input$series %in% ids); set_origin(base_origin(input$series)) }, ignoreInit = TRUE)
    shiny::observeEvent(input$reset, { shiny::updateSelectInput(session, "series", selected = "city"); shiny::updateSliderInput(session, "horizon", value = 6); set_origin(base_origin("city")) })
    origin_epoch <- shiny::reactive({ shiny::req(input$origin_date, input$origin_hour); as.numeric(as.POSIXct(sprintf("%s %s", input$origin_date, input$origin_hour), tz = "UTC")) })
    result <- shiny::reactive({ shiny::req(input$series, input$horizon); tryCatch(forecast_historical(artifacts$forecast, input$series, origin_epoch(), input$horizon), error = function(e) shiny::validate(shiny::need(FALSE, conditionMessage(e)))) })
    output$forecast <- shiny::renderPlot({ d <- result(); d$time <- as.POSIXct(d$epoch, origin = "1970-01-01", tz = "UTC"); ggplot2::ggplot(d, ggplot2::aes(time)) + ggplot2::geom_line(ggplot2::aes(y = observed, colour = "Observado")) + ggplot2::geom_line(ggplot2::aes(y = prediction, colour = "Pronosticado")) + ggplot2::labs(x = NULL, y = "Viajes por hora", colour = NULL) + ggplot2::theme_minimal() })
    output$summary <- shiny::renderTable({ d <- result(); data.frame(serie = names(labels)[match(input$series, labels)], origen_utc = sprintf("%s %s", input$origin_date, input$origin_hour), horizonte_horas = input$horizon, prediccion_final = round(tail(d$prediction, 1)), observado_final = tail(d$observed, 1), mae_ventana = round(mean(abs(d$prediction - d$observed)), 1)) })
    output$note <- shiny::renderUI(htmltools::tagList(
      htmltools::tags$p("Este es un backtest: verifica qué habría estimado el modelo en 2022–2024 y lo contrasta con el valor observado. No es un pronóstico vigente de 2026.", class = "fw-semibold"),
      htmltools::tags$p("Variables usadas: demanda observada 1, 24 y 168 horas antes del origen, hora, día de la semana y mes."),
      htmltools::tags$p("Variables no incluidas: clima (temperatura, lluvia, nieve, viento, visibilidad y alertas extremas); vuelos, llegadas, salidas, demoras y volumen de pasajeros aeroportuarios; eventos deportivos, conciertos, congresos y feriados específicos; tráfico, cierres viales, obras, incidentes y estado del transporte público; tarifas, peajes, recargos, métodos de pago, disponibilidad de conductores o taxis; actividad turística, condiciones económicas y cambios de política o regulación."),
      htmltools::tags$p("Por esas omisiones, el modelo no atribuye causas, no representa demanda no atendida y no debe usarse para precios, incentivos, asignación de flota ni decisiones automáticas.", class = "text-muted")
    ))
  })
}
