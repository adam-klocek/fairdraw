# Self-contained, bilingual, printable HTML. A seal is issued only after replay succeeds.
fd_certificate_html <- function(record) {
  x <- fd_verify(record)
  result <- fd_result_table(record)
  assessed <- fd_evaluate(x$data, x$config, x$previous)
  escape <- function(text) as.character(htmltools::htmlEscape(as.character(text)))
  rows <- vapply(seq_len(nrow(result)), function(i) paste0(
    '<tr class="', tolower(result$Role[i]), '"><td>', result$Order[i], '</td><td class="name">',
    escape(result$Name[i]), '</td><td>', escape(result$ID[i]), '</td><td class="role">',
    fd_role_label(result$Role[i]), '</td></tr>'), character(1))
  time <- as.POSIXct(x$payload$created_utc, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  values <- c("{{DEMO}}" = "", "{{TITLE}}" = escape(x$payload$title), "{{ROWS}}" = paste(rows, collapse = "\n"),
    "{{SERIAL}}" = toupper(substr(record$sha256, 1L, 16L)), "{{TIME_LOCAL}}" = escape(format(time, "%d.%m.%Y %H:%M %Z", tz = "Europe/Prague")),
    "{{TIME_UTC}}" = escape(x$payload$created_utc), "{{ELIGIBLE}}" = sum(assessed$eligible), "{{TOTAL}}" = nrow(x$data),
    "{{WINNERS}}" = x$config$winners, "{{ALTERNATES}}" = x$config$alternates,
    "{{WEIGHT}}" = escape(if (nzchar(x$config$weight_field)) fd_column_label(x$config$weight_field) else "Stejné šance / Equal chances"),
    "{{RULES}}" = length(x$config$rules), "{{HASH_FIRST}}" = substr(record$sha256, 1L, 32L), "{{HASH_SECOND}}" = substr(record$sha256, 33L, 64L))
  template <- paste(readLines(file.path("templates", "certificate.html"), warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  matches <- gregexpr("\\{\\{[A-Z_]+\\}\\}", template, perl = TRUE)
  tokens <- regmatches(template, matches)[[1L]]
  fd_assert(all(tokens %in% names(values)), "Certificate template has missing fields.")
  regmatches(template, matches) <- list(unname(as.character(values[tokens])))
  template
}
