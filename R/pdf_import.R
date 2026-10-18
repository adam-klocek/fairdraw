# Parser for the supplied Czech invoice-export layout. Scans are deliberately rejected.
FD_PDF_COLUMNS <- c("Typ", "Číslo dokladu", "Číslo zákazníka", "Jméno zákazníka", "Lokace",
  "Zúčtovací datum", "Datum dokladu", "Platba", "Částka vč. DPH")
fd_parse_invoice_pdf <- function(pages) {
  fd_assert(length(pages) > 0L && length(pages) <= 500L, "PDF must contain between 1 and 500 pages.")
  text <- paste(pages, collapse = "\n")
  fd_assert(nzchar(trimws(text)), "The PDF has no readable text. Please upload a text PDF or Excel file; scanned PDFs need OCR first.")
  fd_assert(grepl("Číslo\\s+dokladu", text, perl = TRUE) && grepl("Číslo\\s+zákazníka", text, perl = TRUE),
    "This PDF does not match the supported Czech invoice-export template.")
  pattern <- paste0("^\\s*(\\S+)\\s+(\\d+)\\s+(\\d+)\\s+(.+?)\\s+(\\d+(?:-\\d+)?)\\s+",
    "(\\d{2}\\.\\d{2}\\.\\d{4})\\s+(\\d{2}\\.\\d{2}\\.\\d{4})\\s+(\\S+)\\s+",
    "(-?[0-9][0-9 .\u00a0]*,[0-9]{2})\\s*$")
  lines <- unlist(strsplit(text, "\n", fixed = TRUE), use.names = FALSE)
  rows <- list(); unmatched <- integer(); totals <- numeric()
  for (i in seq_along(lines)) {
    line <- trimws(lines[i]); if (!nzchar(line)) next
    match <- regmatches(line, regexec(pattern, line, perl = TRUE))[[1]]
    if (length(match) == 10L) {
      rows[[length(rows) + 1L]] <- match[-1L]
    } else if (grepl("Číslo\\s+dokladu", line, perl = TRUE)) {
      next
    } else if (grepl("^Celkem\\s+", line, perl = TRUE)) {
      amount <- sub("^Celkem\\s+", "", line, perl = TRUE)
      totals <- c(totals, fd_number(amount))
    } else if (grepl("^\\d+\\s*(/|z)\\s*\\d+$", line, perl = TRUE)) {
      next
    } else unmatched <- c(unmatched, i)
  }
  fd_assert(length(unmatched) == 0L, "Some PDF rows could not be read. No data was imported. Use the supplied layout or export to Excel.")
  fd_assert(length(rows) > 0L, "No invoice rows were found in the PDF.")
  data <- as.data.frame(do.call(rbind, rows), stringsAsFactors = FALSE, check.names = FALSE)
  names(data) <- FD_PDF_COLUMNS
  amounts <- fd_number(data[["Částka vč. DPH"]])
  fd_assert(all(is.finite(amounts)), "The PDF contains unreadable amounts.")
  fd_assert(all(!is.na(fd_date(data[["Zúčtovací datum"]]))) && all(!is.na(fd_date(data[["Datum dokladu"]]))), "The PDF contains invalid dates.")
  if (length(totals)) fd_assert(length(totals) == 1L && !is.na(totals) &&
    sum(round(amounts * 100)) == round(totals * 100), "The sum of imported amounts does not match the PDF total. No data was imported.")
  data <- fd_normalize(data)
  attr(data, "pdf_report") <- list(rows = nrow(data), pages = length(pages),
    customers = length(unique(data[["Číslo zákazníka"]])), total = sum(amounts), total_checked = length(totals) == 1L)
  data
}
fd_read_pdf <- function(path) {
  fd_assert(file.info(path)$size <= 10 * 1024^2, "PDF files must be no larger than 10 MB.")
  info <- pdftools::pdf_info(path)
  fd_assert(info$pages >= 1L && info$pages <= 500L, "PDF must contain between 1 and 500 pages.")
  fd_parse_invoice_pdf(pdftools::pdf_text(path))
}
fd_initial_data <- function() {
  path <- file.path("data", "imported-participants.csv")
  if (file.exists(path)) return(fd_normalize(utils::read.csv(path, colClasses = "character", check.names = FALSE,
    stringsAsFactors = FALSE, na.strings = character(), fileEncoding = "UTF-8")))
  fd_normalize(fd_sample())
}
fd_default_id <- function(fields) {
  preferred <- c("Číslo dokladu", "ID")
  found <- preferred[preferred %in% fields]
  if (length(found)) found[1] else fields[1]
}
fd_default_label <- function(fields) {
  preferred <- c("Jméno zákazníka", "Name", "Jméno")
  found <- preferred[preferred %in% fields]
  if (length(found)) found[1] else fd_default_id(fields)
}
