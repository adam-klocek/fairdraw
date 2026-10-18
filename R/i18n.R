# Czech first, English second. Internal field IDs and participant data never change.
FD_CS <- jsonlite::fromJSON(file.path("data", "translations.json"), simplifyVector = FALSE)
fd_bi <- function(text) {
  if (length(text) != 1L) return(vapply(text, fd_bi, character(1), USE.NAMES = FALSE))
  if (is.na(text)) return("")
  cs <- FD_CS[[text]]
  if (is.null(cs) || identical(cs, text)) text else paste(cs, text, sep = " / ")
}
FD_COLUMN_EN <- list("Typ" = "Type", "Číslo dokladu" = "Invoice number", "Číslo zákazníka" = "Customer number",
  "Jméno zákazníka" = "Customer name", "Lokace" = "Location", "Zúčtovací datum" = "Posting date",
  "Datum dokladu" = "Document date", "Platba" = "Payment", "Částka vč. DPH" = "Amount incl. VAT")
FD_SAMPLE_CS <- list(Name = "Jméno", ID = "ID", City = "Město", Membership = "Členství", Points = "Body",
  Minimum_points = "Minimální počet bodů", Opted_in = "Souhlas", Tickets = "Losy", Joined = "Datum registrace")
fd_column_label <- function(field) {
  en <- FD_COLUMN_EN[[field]]; cs <- FD_SAMPLE_CS[[field]]
  if (!is.null(en)) return(paste(field, en, sep = " / "))
  if (!is.null(cs) && !identical(cs, field)) return(paste(cs, field, sep = " / "))
  fd_bi(field)
}
fd_choices <- function(choices) {
  if (is.list(choices)) return(choices)
  labels <- names(choices)
  if (is.null(labels)) labels <- as.character(choices)
  labels[is.na(labels) | labels == ""] <- as.character(choices)[is.na(labels) | labels == ""]
  stats::setNames(unname(choices), vapply(labels, fd_column_label, character(1)))
}
fd_select <- function(inputId, label, choices, ..., selectize = FALSE) {
  shiny::selectInput(inputId, label, choices = fd_choices(choices), ..., selectize = selectize)
}
fd_role_label <- function(role) ifelse(role == "Winner", "Vítěz / Winner", "Náhradník / Alternate")
