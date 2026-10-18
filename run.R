if (!requireNamespace("shiny", quietly = TRUE)) stop("Run source('install.R') first.", call. = FALSE)
shiny::runApp(".", launch.browser = interactive())
