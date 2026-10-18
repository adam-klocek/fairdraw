rule_ui <- function(id, fields, defaults = list()) {
  ns <- shiny::NS(id)
  shiny::tags$div(id = ns("row"), class = "condition-block",
    shiny::tags$div(class = "condition-primary",
      fd_select(ns("field"), fd_bi("Column"), fields, selected = defaults$field %||% fields[1]),
      fd_select(ns("op"), fd_bi("Condition"), fd_operators, selected = defaults$op %||% "eq"),
      shiny::actionButton(ns("remove"), "", icon = shiny::icon("xmark"), class = "remove-rule", title = fd_bi("Remove condition"))),
    shiny::conditionalPanel(
      condition = sprintf("!['blank','notblank'].includes(input['%s'])", ns("op")),
      shiny::tags$div(class = "condition-target",
        fd_select(ns("compare"), fd_bi("Compare with"), c("A value" = "value", "Another column" = "column"), selected = defaults$compare %||% "value"),
        shiny::conditionalPanel(condition = sprintf("input['%s'] !== 'column'", ns("compare")),
          shiny::textInput(ns("value"), fd_bi("Value"), value = defaults$value %||% "", placeholder = fd_bi("Text, number, or YYYY-MM-DD"))),
        shiny::conditionalPanel(condition = sprintf("input['%s'] === 'column'", ns("compare")),
          fd_select(ns("other_field"), fd_bi("Comparison column"), fields, selected = defaults$other_field %||% fields[1])))))
}
rule_server <- function(id, fields, on_remove, defaults = list()) {
  shiny::moduleServer(id, function(input, output, session) {
    shiny::observeEvent(fields(), {
      choices <- fields()
      first <- if (length(choices)) choices[1] else character()
      field <- shiny::isolate(input$field) %||% defaults$field %||% first
      other <- shiny::isolate(input$other_field) %||% defaults$other_field %||% first
      shiny::updateSelectInput(session, "field", choices = fd_choices(choices), selected = if (field %in% choices) field else first)
      shiny::updateSelectInput(session, "other_field", choices = fd_choices(choices), selected = if (other %in% choices) other else first)
    })
    shiny::observeEvent(input$remove, on_remove(id), ignoreInit = TRUE)
    shiny::reactive(list(field = input$field %||% defaults$field %||% fields()[1],
      op = input$op %||% defaults$op %||% "eq", compare = input$compare %||% defaults$compare %||% "value",
      value = input$value %||% defaults$value %||% "", other_field = input$other_field %||% defaults$other_field %||% fields()[1]))
  })
}
