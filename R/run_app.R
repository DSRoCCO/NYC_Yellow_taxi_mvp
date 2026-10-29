#' Run the Shiny MVP
#' @export
run_app <- function(...) shiny::shinyApp(ui = app_ui(), server = app_server, onStart = function() load_artifacts()) |> shiny::runApp(...)
