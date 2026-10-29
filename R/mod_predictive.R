mod_predictive_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::layout_sidebar(
    sidebar = bslib::sidebar(
      shiny::selectInput(ns("series"), "Serie", choices = c("Ciudad de Nueva York" = "city")),
      shiny::sliderInput(ns("horizon"), "Horizonte futuro (horas)", min = 1, max = 168, value = 24),
      shiny::actionButton(ns("reset"), "Restablecer escenario", class = "btn-outline-secondary"),
      htmltools::tags$hr(),
      shiny::uiOutput(ns("cutoff"))
    ),
    bslib::card(bslib::card_header("Pronóstico de corto plazo desde el último registro oficial"), shiny::plotOutput(ns("forecast"), height = 350)),
    bslib::card(bslib::card_header("Resultado y advertencias"), shiny::tableOutput(ns("summary")), shiny::uiOutput(ns("note")))
  )
}

mod_predictive_server <- function(id, artifacts) {
  shiny::moduleServer(id, function(input, output, session) {
    labels <- stats::setNames(
      c("city", paste0("zone_", artifacts$forecast$zones$pickup_zone)),
      c("Ciudad de Nueva York", paste0(artifacts$forecast$zones$Zone, " (", artifacts$forecast$zones$Borough, ")"))
    )
    shiny::updateSelectInput(session, "series", choices = labels, selected = "city")
    output$cutoff <- shiny::renderUI({
      cutoff <- tail(artifacts$forecast$series$city$epoch, 1L)
      htmltools::tags$p("La proyección comienza después del último registro oficial disponible: ", format(as.POSIXct(cutoff, origin = "1970-01-01", tz = "UTC"), "%Y-%m-%d %H:%M UTC"), ".")
    })
    shiny::observeEvent(input$reset, {
      shiny::updateSelectInput(session, "series", selected = "city")
      shiny::updateSliderInput(session, "horizon", value = 24)
    })
    result <- shiny::reactive({
      shiny::req(input$series, input$horizon)
      tryCatch(forecast_future(artifacts$forecast, input$series, input$horizon), error = function(e) shiny::validate(shiny::need(FALSE, conditionMessage(e))))
    })
    output$forecast <- shiny::renderPlot({
      d <- result()
      d$time <- as.POSIXct(d$epoch, origin = "1970-01-01", tz = "UTC")
      ggplot2::ggplot(d, ggplot2::aes(time, prediction)) +
        ggplot2::geom_ribbon(ggplot2::aes(ymin = lower, ymax = upper), fill = "#4C78A8", alpha = 0.18) +
        ggplot2::geom_line(colour = "#007C91", linewidth = 0.8) +
        ggplot2::labs(x = NULL, y = "Viajes estimados por hora", caption = "Banda: intervalo predictivo aproximado al 95% en la escala del modelo.") +
        ggplot2::theme_minimal()
    })
    output$summary <- shiny::renderTable({
      d <- result()
      cutoff <- tail(artifacts$forecast$series[[input$series]]$epoch, 1L)
      data.frame(serie = names(labels)[match(input$series, labels)], corte_datos_utc = format(as.POSIXct(cutoff, origin = "1970-01-01", tz = "UTC"), "%Y-%m-%d %H:%M"), horizonte_horas = input$horizon, objetivo_final_utc = format(as.POSIXct(tail(d$epoch, 1L), origin = "1970-01-01", tz = "UTC"), "%Y-%m-%d %H:%M"), proyeccion_final = round(tail(d$prediction, 1L)), limite_inferior = round(tail(d$lower, 1L)), limite_superior = round(tail(d$upper, 1L)))
    })
    output$note <- shiny::renderUI(htmltools::tagList(
      htmltools::tags$p("Esta es una proyección prospectiva desde el último registro oficial disponible; no equivale a una previsión vigente si existe retraso en la publicación de datos.", class = "fw-semibold"),
      htmltools::tags$p("Después de la primera hora, el modelo reutiliza sus propias predicciones como rezagos; por ello la incertidumbre aumenta con el horizonte. El intervalo es aproximado y no incorpora información posterior al corte."),
      htmltools::tags$p("No incorpora clima, vuelos, demoras aeroportuarias, eventos, tráfico, obras, transporte público, tarifas, disponibilidad de taxis o conductores, turismo, economía, regulación ni cambios posteriores a 2024."),
      htmltools::tags$p("No usar para precios, incentivos, asignación de flota, decisiones automáticas ni inferencia causal.", class = "text-muted")
    ))
  })
}
