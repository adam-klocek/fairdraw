packages <- c("shiny", "DT", "readxl", "writexl", "jsonlite", "openssl", "digest", "stringi", "pdftools")
missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) install.packages(missing, repos = "https://cloud.r-project.org")
message("Závislosti jsou připraveny. Spusťte shiny::runApp() v této složce. / Dependencies ready. Run shiny::runApp() from this folder.")
