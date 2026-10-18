# Run from this project directory with shiny::runApp().
required <- c("shiny", "DT", "readxl", "writexl", "jsonlite", "openssl", "digest", "stringi", "pdftools")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Install missing packages first: install.packages(c(", paste(sprintf('"%s"', missing), collapse = ", "), "))", call. = FALSE)
library(shiny)
source("R/i18n.R", local = TRUE, encoding = "UTF-8")
source("R/engine.R", local = TRUE, encoding = "UTF-8")
source("R/pdf_import.R", local = TRUE, encoding = "UTF-8")
source("R/certificate.R", local = TRUE, encoding = "UTF-8")
source("R/rule_module.R", local = TRUE, encoding = "UTF-8")
options(shiny.maxRequestSize = FD_MAX_RECORD_BYTES)
selectInput <- fd_select
radioButtons <- function(inputId, label, choices, ...) shiny::radioButtons(inputId, label, choices = fd_choices(choices), ...)
initial_data <- fd_initial_data()
initial_fields <- names(initial_data)

panel <- function(title, icon_name, ..., actions = NULL, class = "") {
  tags$section(class = paste("fd-card", class),
    tags$div(class = "card-heading", tags$div(class = "section-title", icon(icon_name), tags$h2(title)), actions), ...)
}
metric <- function(value, label, class = "") tags$div(class = paste("metric", class), tags$strong(value), tags$span(label))

ui <- fluidPage(
  tags$head(tags$title(fd_bi("Fairdraw | Your list. Your rules. Your winner.")),
    tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
    tags$link(rel = "stylesheet", href = "style.css"), tags$link(rel = "stylesheet", href = "accessibility.css"), tags$script(src = "app.js")),
  tags$div(class = "app-shell",
    tags$aside(class = "sidebar",
      tags$div(class = "brand", tags$span(class = "brand-mark", "✳"), "fairdraw", tags$span(class = "brand-dot", ".")),
      tags$div(class = "workspace", tags$span("R"), tags$div(fd_bi("Shiny workspace"), tags$small(fd_bi("Private session")))),
      tags$div(class = "nav-label", fd_bi("WORKSPACE")),
      actionButton("nav_studio", fd_bi("Draw studio"), icon = icon("table-cells-large"), class = "nav-item active"),
      actionButton("nav_history", fd_bi("Draw history"), icon = icon("clock-rotate-left"), class = "nav-item"),
      actionButton("nav_verify", fd_bi("Verify a draw"), icon = icon("shield-halved"), class = "nav-item"),
      tags$div(class = "sidebar-card", tags$span("✳"), tags$h3(fd_bi("A little chance."), tags$br(), fd_bi("A lot of possibility.")),
        tags$p(fd_bi("From your next big giveaway to the small decisions.")), actionButton("new_draw", fd_bi("+ Create a new draw"), class = "sidebar-new")),
      tags$div(class = "sidebar-bottom", actionButton("help", fd_bi("How Fairdraw works"), icon = icon("circle-question")),
        tags$p(icon("lock"), fd_bi("Session data stays separate")), tags$small(fd_bi("Built with R Shiny")))),
    tags$div(class = "main-shell",
      tags$header(class = "topbar", tags$span(fd_bi("Workspace"), tags$span(class = "slash", "/"), tags$strong(textOutput("current_page", inline = TRUE))),
        tags$span(class = "topbar-note", icon("shield-halved"), fd_bi("Your list. Your rules. Your winner."))),
      tabsetPanel(id = "workspace_tabs", type = "hidden",
        tabPanel(fd_bi("Studio"), value = "studio",
          tags$main(
            tags$div(class = "page-heading", tags$div(tags$div(class = "eyebrow", fd_bi("LEAVE IT TO CHANCE. KEEP IT FAIR.")),
              tags$h1(fd_bi("Your next winner starts here"), tags$span(".")), tags$p(fd_bi("Bring your list. Set your conditions. Let a little luck do the rest."))),
              tags$div(class = "sample-actions", actionButton("load_pdf_data", fd_bi("Load supplied PDF data"), icon = icon("file-pdf"), class = "btn-subtle"),
                actionButton("sample", fd_bi("Load sample"), icon = icon("wand-magic-sparkles"), class = "btn-subtle"))),
            tags$div(class = "steps", tags$span(tags$b("1"), fd_bi("Add your entries")), tags$i(), tags$span(tags$b("2"), fd_bi("Set the rules")), tags$i(), tags$span(tags$b("3"), fd_bi("Meet your winner"))),
            tags$div(class = "studio-grid",
              panel(fd_bi("Your entries"), "users", class = "entries-card", actions = tags$div(class = "heading-actions",
                actionButton("show_import", fd_bi("Import list"), icon = icon("file-excel"), class = "btn-primary")),
                tags$div(class = "entry-summary", uiOutput("entry_summary")),
                tags$div(class = "table-controls", selectInput("entry_status", NULL, c("All entries" = "all", "Eligible only" = "eligible", "Excluded only" = "excluded")),
                  downloadLink("download_entries", fd_bi("Export preview"), class = "text-link")),
                DT::DTOutput("entries"), tags$div(class = "eligibility-strip", uiOutput("eligibility_summary"))),
              tags$section(class = "fd-card draw-card", id = "draw-card",
                tags$div(class = "draw-card-top", tags$span(class = "live-label", fd_bi("●  DRAW STUDIO")),
                  tags$button(type = "button", class = "presentation-toggle", title = fd_bi("Presentation mode"), onclick = "Fairdraw.presentation()", icon("expand"))),
                textAreaInput("draw_title", NULL, fd_bi("Community giveaway"), rows = 2),
                radioButtons("reveal", NULL, c("Wheel reveal" = "wheel", "Instant reveal" = "instant"), inline = TRUE),
                tags$div(class = "reveal-stage", id = "reveal-stage",
                  tags$div(class = "wheel-area", tags$div(class = "wheel-pointer"),
                    tags$div(class = "wheel", id = "wheel", tags$span("✳")), tags$span(class = "orbit-spark first", "✦"),
                    tags$span(class = "orbit-spark second", "+"), tags$p(fd_bi("A little spin. A big moment."))),
                  tags$div(id = "spin-progress", class = "spin-progress", role = "status", `aria-live` = "polite", style = "display:none",
                    tags$strong(id = "wheel-countdown", "30 s"), tags$div(class = "spin-track", tags$div(id = "spin-fill")),
                    tags$p(fd_bi("One moment, luck is on its way…")), tags$button(type = "button", class = "btn", id = "skip-reveal", fd_bi("Skip animation")))),
                uiOutput("winner_preview"), uiOutput("pool_summary"),
                actionButton("draw", fd_bi("Pick a winner"), icon = icon("wand-magic-sparkles"), class = "draw-button"),
                uiOutput("draw_message"), tags$p(class = "draw-footnote", icon("shield-halved"), fd_bi("Secure seed · Replayable selection")),
                uiOutput("record_button")),
              panel(fd_bi("Eligibility rules"), "sliders", class = "rules-card", actions = actionButton("add_rule", fd_bi("Add condition"), icon = icon("plus")),
                tags$div(class = "rule-intro", tags$span(fd_bi("Include an entry when")), selectInput("match", NULL, c("all conditions" = "all", "any condition" = "any")), tags$span(fd_bi("are met."))),
                tags$div(id = "rules-list"), uiOutput("rules_empty"),
                tags$div(class = "rule-note", icon("circle-info"), fd_bi("Filter any column. Compare values or compare one column with another."))),
              panel(fd_bi("Draw settings"), "gear", class = "settings-card",
                tags$div(class = "settings-pair", numericInput("winners", fd_bi("Winners"), 1, min = 1, max = 100, step = 1), numericInput("alternates", fd_bi("Alternates"), 0, min = 0, max = 100, step = 1)),
                selectInput("id_field", fd_bi("Unique entry ID"), initial_fields, selected = fd_default_id(initial_fields)),
                selectInput("label_field", fd_bi("Display name"), initial_fields, selected = fd_default_label(initial_fields)),
                tags$p(class = "setting-hint", fd_bi("Invoice number gives one chance per invoice. Customer number with duplicate removal gives one chance per customer.")),
                selectInput("weight_field", fd_bi("Entry weighting"), c("Equal chance for every entry" = "", initial_fields)),
                checkboxInput("dedupe", fd_bi("Remove duplicate IDs"), TRUE), tags$p(class = "setting-hint", fd_bi("Keep the first occurrence; IDs ignore case and spaces.")),
                checkboxInput("exclude_previous", fd_bi("Exclude previous winners"), FALSE), tags$p(class = "setting-hint", fd_bi("Match IDs across this session’s draw history.")),
                tags$p(class = "setting-note", fd_bi("Rows are selected without replacement. Weights must be positive whole numbers.")))),
            tags$footer(class = "page-footer", tags$span(fd_bi("✳  A fair chance for every possibility.")), actionButton("method", fd_bi("How the draw works ↗"))))),
        tabPanel(fd_bi("History"), value = "history", tags$main(tags$div(class = "page-heading", tags$div(tags$div(class = "eyebrow", fd_bi("EVERY MOMENT, ON THE RECORD")),
          tags$h1(fd_bi("Your draw history"), tags$span(".")), tags$p(fd_bi("Draws are kept for this session. Export records before closing the app.")))), uiOutput("history_list"))),
        tabPanel(fd_bi("Verify"), value = "verify", tags$main(tags$div(class = "page-heading", tags$div(tags$div(class = "eyebrow", fd_bi("LOOK BEHIND THE LUCK")),
          tags$h1(fd_bi("Replay a draw"), tags$span(".")), tags$p(fd_bi("Check a Fairdraw JSON record against its locked entry snapshot.")))),
          panel(fd_bi("Verify a draw record"), "shield-halved", class = "verify-card",
            tags$p(fd_bi("Upload an exported audit JSON to check its checksum, eligibility rules, and exact winner selection.")),
            fileInput("verify_file", NULL, accept = c(".json"), buttonLabel = fd_bi("Choose record"), placeholder = fd_bi("No file selected")),
            uiOutput("verify_message"), uiOutput("restore_button"),
            tags$p(class = "honesty-note", fd_bi("A matching replay proves internal consistency. Records are self-issued and are not independently certified or timestamped; an organizer can run another draw.")))))))))
server <- function(input, output, session) {
  rv <- reactiveValues(data = initial_data, source = fd_bi("Supplied PDF export"), history = list(),
    last = NULL, revealed = FALSE, drawing = FALSE, draw_error = NULL, verified = NULL)
  ids <- reactiveVal(character()); rule_modules <- list(); next_id <- 0L
  fields <- reactive(names(rv$data))
  remove_rule <- function(id) {
    removeUI(selector = paste0("#", NS(id)("row")), immediate = TRUE)
    ids(setdiff(ids(), id))
  }
  add_rule <- function(defaults = list()) {
    if (length(ids()) >= 30L) { showNotification(fd_bi("Use at most 30 conditions."), type = "warning"); return(invisible(NULL)) }
    next_id <<- next_id + 1L; id <- paste0("condition_", next_id)
    rule_modules[[id]] <<- rule_server(id, fields, remove_rule, defaults)
    insertUI("#rules-list", where = "beforeEnd", ui = rule_ui(id, fields(), defaults), immediate = TRUE)
    ids(c(ids(), id))
  }
  clear_rules <- function() for (id in ids()) remove_rule(id)
  session$onFlushed(function() {
    withReactiveDomain(session, isolate({if ("Opted_in" %in% fields()) {
      add_rule(list(field = "Opted_in", op = "eq", value = "Yes")); add_rule(list(field = "Points", op = "gte", value = "100"))
    }}))
  }, once = TRUE)
  observeEvent(input$add_rule, add_rule(), ignoreInit = TRUE)
  rules <- reactive(lapply(ids(), function(id) rule_modules[[id]]()))
  config <- reactive(list(id_field = input$id_field %||% fd_default_id(fields()), label_field = input$label_field %||% fd_default_label(fields()),
    weight_field = input$weight_field %||% "", dedupe = isTRUE(input$dedupe), exclude_previous = isTRUE(input$exclude_previous),
    match = input$match %||% "all", rules = rules(), winners = input$winners %||% 1, alternates = input$alternates %||% 0,
    filter_version = FD_FILTER_VERSION))
  previous <- reactive(fd_prior_winners(rv$history))
  assessment <- reactive(tryCatch(list(data = fd_evaluate(rv$data, config(), previous()), error = NULL),
    error = function(e) list(data = NULL, error = conditionMessage(e))))
  pool <- reactive({req(assessment()$data); assessment()$data[assessment()$data$eligible, , drop = FALSE]})
  preview_data <- reactive({
    a <- assessment()
    if (is.null(a$data)) return(data.frame(Message = a$error))
    data <- rv$data
    appended <- tail(make.unique(c(names(data), fd_bi("Draw status"), fd_bi("Exclusion reason"), fd_bi("Draw weight"), fd_bi("First-pick chance (%)"))), 4L)
    data[[appended[1]]] <- ifelse(a$data$eligible, fd_bi("Eligible"), fd_bi("Excluded"))
    data[[appended[2]]] <- a$data$reason
    data[[appended[3]]] <- a$data$weight
    data[[appended[4]]] <- ifelse(a$data$eligible, round(100 * a$data$weight / sum(a$data$weight[a$data$eligible]), 4), 0)
    keep <- switch(input$entry_status %||% "all", eligible = a$data$eligible, excluded = !a$data$eligible, rep(TRUE, nrow(data)))
    data[keep, , drop = FALSE]
  })
  output$entries <- DT::renderDT({
    data <- preview_data()
    DT::datatable(data, colnames = vapply(names(data), fd_column_label, character(1)), rownames = FALSE, escape = TRUE, selection = "none", class = "stripe hover compact",
      options = list(pageLength = 8, lengthMenu = c(8, 25, 50, 100), scrollX = TRUE, autoWidth = FALSE,
        dom = "ftip", language = list(search = "", searchPlaceholder = fd_bi("Search entries…"), emptyTable = fd_bi("No entries in this view."),
          info = "Položky _START_–_END_ z _TOTAL_ / Entries _START_–_END_ of _TOTAL_", infoEmpty = "Žádné položky / No entries", zeroRecords = "Žádná shoda / No matching entries",
          infoFiltered = "(z celkem _MAX_ / from _MAX_ total)", processing = "Načítání… / Loading…",
          paginate = list(previous = "Předchozí / Previous", `next` = "Další / Next", first = "První / First", last = "Poslední / Last"))))
  }, server = TRUE)
  output$entry_summary <- renderUI(tags$span(tags$strong(format(nrow(rv$data), big.mark = ",")), fd_bi(" entries"), tags$span(class = "source-label", rv$source)))
  output$eligibility_summary <- renderUI({
    a <- assessment()
    if (is.null(a$data)) return(tags$span(class = "error-text", a$error))
    tags$div(tags$span(class = "eligible-dot"), tags$strong(sum(a$data$eligible)), fd_bi(" eligible for this draw"), tags$span(class = "excluded-caption", paste(sum(!a$data$eligible), fd_bi("excluded · reasons in the table"))))
  })
  output$rules_empty <- renderUI(if (!length(ids())) tags$p(class = "rules-empty", fd_bi("Everyone’s invited. Add a condition to narrow your pool.")))
  output$pool_summary <- renderUI({
    a <- assessment(); eligible <- if (is.null(a$data)) 0L else sum(a$data$eligible)
    tags$div(class = "draw-stat", tags$span(eligible, fd_bi(" eligible entries")), tags$span(if (nzchar(input$weight_field %||% "")) fd_bi("Weighted chances") else fd_bi("Equal chances")))
  })
  output$current_page <- renderText(switch(input$workspace_tabs %||% "studio", studio = fd_bi("Draw studio"), history = fd_bi("Draw history"), verify = fd_bi("Verify a draw")))
  for (view in c("studio", "history", "verify")) local({
    target <- view
    observeEvent(input[[paste0("nav_", target)]], updateTabsetPanel(session, "workspace_tabs", selected = target), ignoreInit = TRUE)
  })
  observeEvent(input$workspace_tabs, session$sendCustomMessage("fd-nav", input$workspace_tabs))

  set_data <- function(data, source, sample_rules = FALSE) {
    rv$data <- data; rv$source <- source; rv$draw_error <- NULL
    rv$last <- NULL; rv$revealed <- FALSE; rv$drawing <- FALSE
    clear_rules()
    nms <- names(data)
    id <- fd_default_id(nms); label <- fd_default_label(nms)
    updateSelectInput(session, "id_field", choices = fd_choices(nms), selected = id)
    updateSelectInput(session, "label_field", choices = fd_choices(nms), selected = label)
    updateSelectInput(session, "weight_field", choices = fd_choices(c("Equal chance for every entry" = "", nms)), selected = "")
    if (sample_rules) { add_rule(list(field = "Opted_in", op = "eq", value = "Yes")); add_rule(list(field = "Points", op = "gte", value = "100")) }
  }
  observeEvent(input$sample, {
    if (isTRUE(rv$drawing)) {showNotification(fd_bi("Please wait for the current reveal to finish.")); return(invisible(NULL))}
    set_data(fd_normalize(fd_sample()), fd_bi("Sample data · 24 entries"), TRUE)
    showNotification(fd_bi("Sample loaded. Try Points ≥ Minimum_points using 'Another column'."), type = "message")
  }, ignoreInit = TRUE)
  observeEvent(input$load_pdf_data, {
    if (isTRUE(rv$drawing)) {showNotification(fd_bi("Please wait for the current reveal to finish.")); return(invisible(NULL))}
    set_data(fd_initial_data(), fd_bi("Supplied PDF export"))
  }, ignoreInit = TRUE)
  observeEvent(input$new_draw, {
    if (isTRUE(rv$drawing)) {showNotification(fd_bi("Please wait for the current reveal to finish.")); return(invisible(NULL))}
    updateTabsetPanel(session, "workspace_tabs", selected = "studio"); updateTextAreaInput(session, "draw_title", value = fd_bi("Untitled draw"))
    rv$last <- NULL; rv$revealed <- FALSE; rv$draw_error <- NULL; rv$drawing <- FALSE
    showNotification(fd_bi("New draw started with your current entries and rules. Import a list to replace the entries."))
  }, ignoreInit = TRUE)

  show_import <- function() showModal(modalDialog(title = tags$div(class = "modal-title-wrap", tags$span(class = "eyebrow", fd_bi("A GOOD DRAW STARTS WITH A GOOD LIST")), fd_bi("Bring everyone along.")),
    tags$p(fd_bi("Import Excel or PDF, or paste a list. Entries change only when you confirm the import.")),
    tabsetPanel(id = "import_method",
      tabPanel(fd_bi("Excel workbook"), value = "excel", fileInput("excel_file", fd_bi("Excel table"), accept = c(".xlsx", ".xls"), buttonLabel = fd_bi("Choose Excel file"), placeholder = fd_bi("No file selected")),
        uiOutput("sheet_input"), tags$div(class = "settings-pair", numericInput("skip_rows", fd_bi("Rows to skip before header"), 0, min = 0, max = 10000, step = 1),
          checkboxInput("excel_headers", fd_bi("First row is a header"), TRUE)), checkboxInput("excel_text", fd_bi("Read every column as text"), FALSE),
        tags$p(class = "hint", fd_bi("Use text cells in Excel for identifiers with leading zeros. Formulas use their last saved results; save the workbook in Excel first.")),
        tags$strong(fd_bi("Worksheet preview")), tableOutput("excel_preview")),
      tabPanel(fd_bi("PDF export"), value = "pdf", fileInput("pdf_file", fd_bi("PDF export"), accept = ".pdf", buttonLabel = fd_bi("Choose PDF file"), placeholder = fd_bi("No file selected")),
        tags$p(class = "hint", fd_bi("This importer supports text-based PDFs matching the supplied Czech invoice table. Scans and other layouts must be converted to Excel first.")),
        uiOutput("pdf_report"), tags$strong(fd_bi("PDF table preview")), tags$div(class = "pdf-preview", tableOutput("pdf_preview"))),
      tabPanel(fd_bi("Paste a list"), value = "paste", textAreaInput("paste_text", NULL, rows = 8,
        placeholder = "Name,City,Points,Opted_in\nSofia Novak,Prague,180,Yes\nAlex Chen,Berlin,80,No"),
        checkboxInput("paste_headers", fd_bi("First row contains column headers"), TRUE),
        tags$p(class = "hint", fd_bi("One name per line, CSV, semicolon-separated data, or tab-separated cells copied from Excel. A single column is always treated as a name list.")))),
    tags$p(class = "hint", fd_bi("Up to 50,000 entries, 200 columns, and 10 MB per upload.")),
    tags$div(class = "template-link", downloadLink("template", fd_bi("Download sample Excel workbook ↗"))),
    footer = tagList(modalButton(fd_bi("Cancel")), actionButton("commit_import", fd_bi("Import entries →"), class = "btn-primary")), size = "l", easyClose = TRUE))
  observeEvent(input$show_import, show_import(), ignoreInit = TRUE)
  pdf_data <- reactive({
    req(input$pdf_file)
    fd_assert(tolower(tools::file_ext(input$pdf_file$name)) == "pdf", "Choose a PDF file first.")
    fd_read_pdf(input$pdf_file$datapath)
  })
  output$pdf_preview <- renderTable({
    req(input$pdf_file)
    tryCatch({data <- head(pdf_data(), 5); names(data) <- vapply(names(data), fd_column_label, character(1)); data},
      error = function(e) data.frame(Message = conditionMessage(e)))
  }, striped = TRUE, spacing = "s", rownames = FALSE)
  output$pdf_report <- renderUI({
    req(input$pdf_file)
    tryCatch({
      report <- attr(pdf_data(), "pdf_report")
      tags$div(class = "verification-message", paste(report$rows, fd_bi("rows"), "·", report$pages, fd_bi("pages"), "·", report$customers, fd_bi("customers")),
        tags$p(paste(fd_bi("Total amount"), format(report$total, big.mark = " ", decimal.mark = ",", nsmall = 2))),
        tags$strong(fd_bi(if (report$total_checked) "PDF total checked" else "PDF has no total line")))
    }, error = function(e) tags$p(class = "error-text", conditionMessage(e)))
  })
  sheet_names <- reactive({
    req(input$excel_file)
    fd_assert(tolower(tools::file_ext(input$excel_file$name)) %in% c("xlsx", "xls"), fd_bi("Choose an .xlsx or .xls file."))
    fd_assert(input$excel_file$size <= 10 * 1024^2, fd_bi("Excel workbooks must be no larger than 10 MB."))
    readxl::excel_sheets(input$excel_file$datapath)
  })
  output$sheet_input <- renderUI({
    req(input$excel_file)
    sheets <- tryCatch(sheet_names(), error = function(e) e)
    if (inherits(sheets, "error")) return(tags$p(class = "error-text", conditionMessage(sheets)))
    selectInput("excel_sheet", fd_bi("Worksheet"), choices = sheets, selected = sheets[1])
  })
  output$excel_preview <- renderTable({
    req(input$excel_file, input$excel_sheet)
    tryCatch({
      x <- readxl::read_excel(input$excel_file$datapath, sheet = input$excel_sheet,
        skip = input$skip_rows %||% 0, col_names = isTRUE(input$excel_headers), n_max = 5,
        col_types = if (isTRUE(input$excel_text)) "text" else NULL, .name_repair = "unique", progress = FALSE)
      x <- as.data.frame(x, check.names = FALSE)
      names(x) <- vapply(names(x), fd_column_label, character(1)); x
    }, error = function(e) data.frame(Message = conditionMessage(e)))
  }, striped = TRUE, bordered = FALSE, spacing = "s", rownames = FALSE)
  observeEvent(input$commit_import, {
    tryCatch({
      if (identical(input$import_method, "excel")) {
        fd_assert(!is.null(input$excel_file) && !is.null(input$excel_sheet), fd_bi("Choose an Excel file and worksheet first."))
        fd_assert(input$excel_file$size <= 10 * 1024^2, fd_bi("Excel workbooks must be no larger than 10 MB."))
        data <- fd_read_excel(input$excel_file$datapath, input$excel_sheet, input$skip_rows %||% 0, isTRUE(input$excel_headers), isTRUE(input$excel_text))
        source <- paste(input$excel_file$name, input$excel_sheet, sep = " · ")
      } else if (identical(input$import_method, "pdf")) {
        fd_assert(!is.null(input$pdf_file), "Choose a PDF file first.")
        data <- pdf_data(); source <- input$pdf_file$name
      } else { data <- fd_read_text(input$paste_text %||% "", isTRUE(input$paste_headers)); source <- fd_bi("Pasted list") }
      set_data(data, source); removeModal()
      showNotification(paste(nrow(data), fd_bi("entries imported. Choose your ID and display columns, then add conditions.")), type = "message")
    }, error = function(e) showNotification(conditionMessage(e), type = "error", duration = 8))
  }, ignoreInit = TRUE)
  output$template <- downloadHandler(filename = function() "fairdraw-sample.xlsx", content = function(file) writexl::write_xlsx(list(Participants = fd_sample()), file))
  output$download_entries <- downloadHandler(filename = function() "fairdraw-eligibility-preview.csv", content = function(file) {
    write.csv(fd_export_safe(preview_data()), file, row.names = FALSE, na = "", fileEncoding = "UTF-8")
  })

  observeEvent(input$draw, {
    if (isTRUE(rv$drawing)) return(invisible(NULL))
    rv$draw_error <- NULL
    tryCatch({
      cfg <- config()
      fd_assert(all(is.finite(c(cfg$winners, cfg$alternates))) && cfg$winners >= 1 && cfg$alternates >= 0 &&
        all(c(cfg$winners, cfg$alternates) == floor(c(cfg$winners, cfg$alternates))) && cfg$winners <= 100 && cfg$alternates <= 100,
        fd_bi("Choose 1–100 winners and 0–100 alternates, using whole numbers."))
      title <- trimws(input$draw_title %||% ""); if (!nzchar(title)) title <- fd_bi("Untitled draw")
      record <- fd_make_record(rv$data, cfg, previous(), title)
      rv$last <- record; rv$history <- c(list(record), rv$history); rv$revealed <- FALSE; rv$drawing <- TRUE
      session$sendCustomMessage("fd-reveal", list(mode = input$reveal %||% "wheel", token = record$sha256, duration = 30000L))
    }, error = function(e) {rv$drawing <- FALSE; rv$draw_error <- conditionMessage(e)})
  }, ignoreInit = TRUE)
  observeEvent(input$reveal_done, {
    if (!is.null(rv$last) && identical(input$reveal_done$token, rv$last$sha256)) { rv$revealed <- TRUE; rv$drawing <- FALSE }
  }, ignoreInit = TRUE)
  output$draw_message <- renderUI(if (!is.null(rv$draw_error)) tags$div(class = "inline-error", rv$draw_error))
  output$winner_preview <- renderUI({
    if (is.null(rv$last) || !isTRUE(rv$revealed)) return(NULL)
    winners <- fd_result_table(rv$last); winners <- winners[winners$Role == "Winner", , drop = FALSE]
    tags$div(class = "winner-preview", tags$span(class = "winner-star", "✳"), tags$div(class = "winner-kicker", fd_bi("MEET YOUR WINNER")),
      tags$h3(winners$Name[1]), tags$p(if (nrow(winners) > 1L) paste(fd_bi("and"), nrow(winners) - 1L, fd_bi("more winner(s)")) else paste(fd_bi("Entry"), winners$ID[1])),
      tags$small(fd_bi("Selected from the locked draw snapshot.")))
  })
  observeEvent(rv$revealed, {
    session$sendCustomMessage("fd-result-visible", isTRUE(rv$revealed))
    updateActionButton(session, "draw", label = if (isTRUE(rv$revealed)) fd_bi("Run another draw") else fd_bi("Pick a winner"))
  }, ignoreInit = FALSE)
  output$record_button <- renderUI(if (!is.null(rv$last) && isTRUE(rv$revealed)) actionButton("view_record", fd_bi("View draw record & share →"), class = "text-button"))
  selected_record <- reactiveVal(NULL)
  show_record <- function(record) {
    selected_record(record); x <- fd_unpack(record); result <- fd_result_table(record)
    assessed <- fd_evaluate(x$data, x$config, x$previous)
    conditions <- if (length(x$config$rules)) vapply(x$config$rules, fd_rule_text, character(1)) else fd_bi("No eligibility conditions")
    showModal(modalDialog(title = x$payload$title,
      tags$div(class = "record-winners", lapply(seq_len(nrow(result)), function(i) tags$div(class = paste("record-winner", tolower(result$Role[i])),
        tags$b(result$Order[i]), tags$strong(result$Name[i]), tags$span(paste(fd_role_label(result$Role[i]), "·", result$ID[i]))))),
      tags$div(class = "record-facts", metric(sum(assessed$eligible), fd_bi("Eligible entries")), metric(nrow(x$data), fd_bi("Total entries")),
        metric(x$payload$created_utc, fd_bi("Time in UTC")), metric(if (nzchar(x$config$weight_field)) x$config$weight_field else fd_bi("Equal chances"), fd_bi("Entry weighting"))),
      tags$div(class = "record-rules", tags$strong(fd_bi(if (identical(x$config$match, "all")) "all conditions" else "any condition")), tags$ul(lapply(conditions, tags$li))),
      tags$div(class = "hash-box", tags$strong("KONTROLNÍ SOUČET ZÁZNAMU / RECORD SHA-256"), tags$code(record$sha256)),
      tags$div(class = "record-actions", downloadButton("audit_json", fd_bi("Audit JSON"), class = "btn-primary"), downloadButton("results_excel", fd_bi("Results Excel")), downloadButton("certificate", fd_bi("Certificate"))),
      tags$p(class = "hint", fd_bi("Audit JSON includes all entries and rules. Results Excel and the certificate include selected entries only. Records are self-issued, not independently certified.")),
      footer = modalButton(fd_bi("Close")), size = "l", easyClose = TRUE))
  }
  observeEvent(input$view_record, {req(rv$last); show_record(rv$last)}, ignoreInit = TRUE)
  output$history_list <- renderUI({
    if (!length(rv$history)) return(tags$div(class = "fd-card empty-state", tags$h2(fd_bi("Your first winner is waiting.")), tags$p(fd_bi("Run a draw to start its story here."))))
    tagList(lapply(seq_along(rv$history), function(i) {
      record <- rv$history[[i]]; x <- fd_unpack(record); result <- fd_result_table(record)
      tags$div(class = "fd-card history-item", tags$span(class = "history-star", "✳"), tags$div(tags$h3(x$payload$title), tags$p(x$payload$created_utc),
        tags$small(paste(result$Name[result$Role == "Winner"], collapse = ", "))),
        tags$button(type = "button", class = "btn btn-default", onclick = sprintf("Shiny.setInputValue('history_open', %d, {priority:'event'})", i), fd_bi("View record ↗")))
    }))
  })
  observeEvent(input$history_open, {
    index <- as.integer(input$history_open)
    if (length(index) == 1L && !is.na(index) && index >= 1L && index <= length(rv$history)) show_record(rv$history[[index]])
  }, ignoreInit = TRUE)
  output$audit_json <- downloadHandler(filename = function() paste0("fairdraw-", substr(selected_record()$sha256, 1, 10), ".json"),
    content = function(file) {req(selected_record()); writeLines(fd_json(selected_record(), pretty = TRUE), file, useBytes = TRUE)}, contentType = "application/json")
  output$results_excel <- downloadHandler(filename = function() "fairdraw-results.xlsx", content = function(file) {
    req(selected_record()); result <- fd_result_table(selected_record())
    result$Role <- fd_role_label(result$Role)
    names(result) <- c("Pořadí / Order", "Výsledek / Result", "ID", "Jméno / Name")
    writexl::write_xlsx(list(Vysledky_Results = result), file)
  })
  output$certificate <- downloadHandler(filename = function() "fairdraw-certifikat-certificate.html", content = function(file) {
    req(selected_record())
    writeLines(fd_certificate_html(selected_record()), file, useBytes = TRUE)
  }, contentType = "text/html")
  observeEvent(input$verify_file, {
    rv$verified <- NULL
    tryCatch({
      fd_assert(input$verify_file$size <= FD_MAX_RECORD_BYTES, fd_bi("Record exceeds 50 MB."))
      record <- jsonlite::fromJSON(input$verify_file$datapath, simplifyVector = FALSE)
      fd_verify(record); rv$verified <- record
      output$verify_message <- renderUI(tags$div(class = "verification-message", tags$strong(fd_bi("Checksum and replay match.")), tags$p(fd_bi("The recorded rules produce the same eligible pool and the exact same winners and alternates."))))
    }, error = function(e) {message <- conditionMessage(e); output$verify_message <- renderUI(tags$div(class = "verification-message bad", message))})
  }, ignoreInit = TRUE)
  output$restore_button <- renderUI(if (!is.null(rv$verified)) actionButton("restore_record", fd_bi("Add verified draw to this session’s history"), class = "btn-primary"))
  observeEvent(input$restore_record, {
    req(rv$verified)
    if (!rv$verified$sha256 %in% vapply(rv$history, `[[`, character(1), "sha256")) rv$history <- c(list(rv$verified), rv$history)
    showNotification(fd_bi("Record added to history. Its winners can now be excluded from new draws."), type = "message")
  }, ignoreInit = TRUE)
  show_help <- function() showModal(modalDialog(title = fd_bi("A fair chance, made simple."),
    tags$div(class = "help-steps", tags$h3(fd_bi("1. Import Excel, PDF, or a list")), tags$p(fd_bi("Upload Excel, choose its worksheet and header row, or import a text PDF in the supplied invoice layout. You can also paste names or copied cells.")),
      tags$h3(fd_bi("2. Set contextual conditions")), tags$p(fd_bi("Filter any column by text, numbers (including decimal commas), or dates (DD.MM.YYYY or YYYY-MM-DD). Compare with a fixed value or another column. Match ALL or ANY conditions.")),
      tags$h3(fd_bi("3. Pick your winners")), tags$p(fd_bi("Rows are selected without replacement, with optional whole-number weights. The wheel reveals the recorded result over 30 seconds. Instant reveal, Skip animation, or reduced-motion preferences can show it immediately.")),
      tags$h3(fd_bi("4. Keep the record")), tags$p(fd_bi("Every draw uses a fresh 256-bit cryptographic seed and a locked snapshot of entries, rules, and previous winners. The algorithm derives unbiased integer samples from SHA-256 using rejection sampling. Export audit JSON to replay it. Checksums and replay demonstrate internal consistency, not independent certification or proof that a draw was not repeated.")),
      tags$p(fd_bi("Session history disappears when the Shiny session ends. Import exported JSON records through Verify a draw to restore history. On a hosted Shiny server, uploaded data is processed on that server and isolated by session."))),
    footer = modalButton(fd_bi("Got it")), size = "l", easyClose = TRUE))
  observeEvent(input$help, show_help(), ignoreInit = TRUE)
  observeEvent(input$method, show_help(), ignoreInit = TRUE)
}
shinyApp(ui, server)
