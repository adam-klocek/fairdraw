# Pure import, filtering, and selection functions. No Shiny session state lives here.
FD_MAX_ROWS <- 50000L
FD_MAX_TOTAL <- 4294967295
FD_MAX_RECORD_BYTES <- 50 * 1024^2
FD_ALGORITHM <- "sha256-counter-rejection-v1"
FD_FILTER_VERSION <- 2L
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x
fd_key <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  stringi::stri_trans_tolower(trimws(enc2utf8(x)), locale = "en")
}
fd_hash <- function(text) digest::digest(enc2utf8(text), algo = "sha256", serialize = FALSE)
fd_json <- function(x, pretty = FALSE) as.character(jsonlite::toJSON(
  x, auto_unbox = TRUE, null = "null", na = "null", digits = NA, pretty = pretty
))
fd_assert <- function(ok, message) if (!isTRUE(ok)) stop(fd_bi(message), call. = FALSE)
fd_number <- function(x, format_version = 2L) {
  x <- trimws(as.character(x))
  if (format_version >= 2L) {
    x <- gsub("[[:space:]\u00a0\u202f]", "", x, perl = TRUE)
    comma <- grepl(",", x, fixed = TRUE)
    # Czech grouping (1.234,56) is supported; ambiguous US comma grouping is rejected.
    ambiguous <- comma & grepl(".", x, fixed = TRUE) & regexpr(",", x, fixed = TRUE) < regexpr(".", x, fixed = TRUE)
    x[ambiguous] <- NA_character_
    x[comma & !ambiguous] <- gsub(",", ".", gsub(".", "", x[comma & !ambiguous], fixed = TRUE), fixed = TRUE)
  }
  result <- suppressWarnings(as.numeric(x))
  result[!nzchar(x) | !is.finite(result)] <- NA_real_
  result
}
fd_date <- function(x, format_version = 2L) {
  x <- trimws(as.character(x))
  if (format_version >= 2L) {
    czech <- grepl("^\\d{2}\\.\\d{2}\\.\\d{4}$", x)
    x[czech] <- sub("^(\\d{2})\\.(\\d{2})\\.(\\d{4})$", "\\3-\\2-\\1", x[czech])
  }
  result <- suppressWarnings(as.Date(x, format = "%Y-%m-%d"))
  valid <- !is.na(result) & grepl("^\\d{4}-\\d{2}-\\d{2}$", x)
  valid[valid] <- format(result[valid], "%Y-%m-%d") == x[valid]
  result[!valid] <- as.Date(NA)
  result
}
fd_normalize <- function(data) {
  data <- as.data.frame(data, stringsAsFactors = FALSE, check.names = FALSE)
  fd_assert(ncol(data) > 0L, "No columns were found.")
  headers <- trimws(enc2utf8(names(data)))
  fd_assert(all(nzchar(headers)) && !anyDuplicated(headers), "Headers must be non-empty and unique.")
  fd_assert(ncol(data) <= 200L, "Use at most 200 columns.")
  fd_assert(nrow(data) <= FD_MAX_ROWS, "Use at most 50,000 entries.")
  names(data) <- headers
  data[] <- lapply(data, function(x) {
    missing <- is.na(x)
    if (inherits(x, "POSIXt") || inherits(x, "Date")) x <- format(x, "%Y-%m-%d", tz = "UTC")
    if (is.numeric(x)) x <- format(x, scientific = FALSE, trim = TRUE, digits = 15)
    x <- as.character(x); x[missing | is.na(x)] <- ""; trimws(enc2utf8(x))
  })
  # Ignore rows that are wholly empty, but preserve rows with a missing ID for review.
  keep <- if (nrow(data)) Reduce(`|`, lapply(data, nzchar)) else logical()
  data <- data[keep, , drop = FALSE]
  rownames(data) <- NULL
  fd_assert(nrow(data) > 0L, "The list has no entries.")
  data
}
fd_read_excel <- function(path, sheet = 1, skip = 0L, headers = TRUE, as_text = FALSE) {
  data <- readxl::read_excel(path, sheet = sheet, skip = skip, col_names = headers,
    col_types = if (as_text) "text" else NULL, n_max = FD_MAX_ROWS + 1L,
    guess_max = FD_MAX_ROWS, .name_repair = "minimal", progress = FALSE)
  if (!headers) names(data) <- paste0("Column ", seq_len(ncol(data)))
  fd_normalize(data)
}
fd_read_text <- function(text, headers = TRUE) {
  text <- sub("^\ufeff", "", text)
  fd_assert(nzchar(trimws(text)), "Paste a list first.")
  separators <- c("\t", ",", ";")
  count_fields <- function(separator) {
    con <- textConnection(text); on.exit(close(con))
    counts <- utils::count.fields(con, sep = separator, quote = "\"", comment.char = "", blank.lines.skip = TRUE)
    counts <- counts[!is.na(counts)]
    if (length(counts)) counts[1] - 1L else 0L
  }
  counts <- vapply(separators, count_fields, integer(1))
  if (!any(counts > 0L)) {
    lines <- strsplit(text, "\n", fixed = TRUE)[[1]]
    return(fd_normalize(data.frame(Name = trimws(lines), check.names = FALSE)))
  }
  separator <- separators[which.max(counts)]
  fields_con <- textConnection(text)
  field_counts <- tryCatch(utils::count.fields(fields_con, sep = separator, quote = "\"", comment.char = "", blank.lines.skip = TRUE), finally = close(fields_con))
  complete <- field_counts[!is.na(field_counts)]
  fd_assert(length(complete) > 0L && all(complete == complete[1]), "Every record must have the same number of columns as its header.")
  con <- textConnection(text); on.exit(close(con))
  data <- withCallingHandlers(utils::read.table(con, sep = separator, header = headers,
    quote = "\"", comment.char = "", check.names = FALSE, colClasses = "character",
    na.strings = character(), fill = FALSE, stringsAsFactors = FALSE,
    nrows = FD_MAX_ROWS + 1L, strip.white = TRUE, row.names = NULL),
    warning = function(w) stop(conditionMessage(w), call. = FALSE))
  if (!headers) names(data) <- paste0("Column ", seq_len(ncol(data)))
  fd_normalize(data)
}
fd_operators <- c("is" = "eq", "is not" = "neq", "contains" = "contains",
  "does not contain" = "notcontains", "is one of (comma-separated)" = "in",
  "is at least" = "gte", "is at most" = "lte", "is greater than" = "gt",
  "is less than" = "lt", "is before date" = "before", "is after date" = "after",
  "is empty" = "blank", "is not empty" = "notblank")
fd_rule_text <- function(rule) {
  operator <- fd_bi(names(fd_operators)[match(rule$op, fd_operators)])
  target <- if (identical(rule$compare, "column")) paste0("[", fd_column_label(rule$other_field), "]") else paste0('"', rule$value, '"')
  paste(fd_column_label(rule$field), operator, if (rule$op %in% c("blank", "notblank")) "" else target)
}
fd_validate_rules <- function(data, config) {
  format_version <- config$filter_version %||% 1L
  for (r in config$rules) {
    fd_assert(r$field %in% names(data), "A condition refers to a column that is no longer in the list.")
    fd_assert(r$op %in% unname(fd_operators), "Unknown condition operator.")
    if (r$op %in% c("blank", "notblank")) next
    if (identical(r$compare, "column")) {
      fd_assert(r$other_field %in% names(data), "Choose a comparison column for every condition.")
      fd_assert(r$op != "in", "Use a literal comma-separated list for 'is one of'.")
    } else {
      fd_assert(nzchar(trimws(r$value %||% "")), "Enter a value for every condition; use 'is empty' to match blanks.")
      if (r$op %in% c("gte", "lte", "gt", "lt")) fd_assert(!is.na(fd_number(r$value, format_version)), "Numeric conditions need a number, for example 100 or 2.5.")
      if (r$op %in% c("before", "after")) fd_assert(!is.na(fd_date(r$value, format_version)),
        if (format_version >= 2L) "Use dates in DD.MM.YYYY or YYYY-MM-DD format." else "Date conditions need a valid YYYY-MM-DD date.")
    }
  }
  invisible(TRUE)
}
fd_matches <- function(data, rule, format_version = 2L) {
  a <- fd_key(data[[rule$field]])
  b <- if (identical(rule$compare, "column")) fd_key(data[[rule$other_field]]) else rep(fd_key(rule$value), nrow(data))
  result <- switch(rule$op,
    eq = a == b, neq = a != b,
    contains = mapply(function(x, y) grepl(y, x, fixed = TRUE), a, b, USE.NAMES = FALSE),
    notcontains = !mapply(function(x, y) grepl(y, x, fixed = TRUE), a, b, USE.NAMES = FALSE),
    `in` = a %in% trimws(strsplit(fd_key(rule$value), ",", fixed = TRUE)[[1]]),
    blank = a == "", notblank = a != "",
    gte = fd_number(a, format_version) >= fd_number(b, format_version), lte = fd_number(a, format_version) <= fd_number(b, format_version),
    gt = fd_number(a, format_version) > fd_number(b, format_version), lt = fd_number(a, format_version) < fd_number(b, format_version),
    before = fd_date(a, format_version) < fd_date(b, format_version), after = fd_date(a, format_version) > fd_date(b, format_version),
    stop("Unknown condition operator.", call. = FALSE))
  # Missing numeric/date values never meet a numeric/date condition.
  result[is.na(result)] <- FALSE
  as.logical(result)
}
fd_evaluate <- function(data, config, previous = character()) {
  fd_assert(config$id_field %in% names(data), "Choose a valid ID column.")
  fd_assert(config$label_field %in% names(data), "Choose a valid display column.")
  fd_validate_rules(data, config)
  n <- nrow(data); ids <- fd_key(data[[config$id_field]])
  reasons <- rep("", n)
  add <- function(mask, text) {
    text <- fd_bi(text)
    reasons[mask] <<- ifelse(nzchar(reasons[mask]), paste(reasons[mask], text, sep = "; "), text)
  }
  add(!nzchar(ids), "Missing entry ID")
  if (isTRUE(config$dedupe)) add(duplicated(ids), "Duplicate ID: first occurrence kept")
  if (isTRUE(config$exclude_previous)) add(ids %in% fd_key(previous), "Won a previous draw")
  checks <- lapply(config$rules, function(r) fd_matches(data, r, config$filter_version %||% 1L))
  if (length(checks)) {
    passes <- if (identical(config$match, "any")) Reduce(`|`, checks) else Reduce(`&`, checks)
    for (i in seq_along(checks)) add(!passes & !checks[[i]], fd_rule_text(config$rules[[i]]))
  }
  weights <- rep(1, n)
  if (nzchar(config$weight_field %||% "")) {
    fd_assert(config$weight_field %in% names(data), "Choose a valid weight column.")
    weights <- fd_number(data[[config$weight_field]], config$filter_version %||% 1L)
    bad <- is.na(weights) | weights <= 0 | weights != floor(weights) | weights > FD_MAX_TOTAL
    add(bad, "Weight must be a positive whole number")
  }
  data.frame(row = seq_len(n), id = as.character(data[[config$id_field]]),
    eligible = !nzchar(reasons), reason = reasons, weight = weights, stringsAsFactors = FALSE)
}
fd_pick <- function(pool, count, seed_hex) {
  fd_assert(nrow(pool) >= 1L, "No entries meet the current conditions.")
  fd_assert(length(count) == 1L && is.finite(count) && count >= 1 && count == floor(count) && count <= nrow(pool),
    "Winners plus alternates must fit the eligible pool.")
  fd_assert(all(is.finite(pool$weight) & pool$weight >= 1 & pool$weight == floor(pool$weight)), "Invalid entry weights.")
  fd_assert(sum(pool$weight) <= FD_MAX_TOTAL, "Total eligible weight must be below 4,294,967,296.")
  fd_assert(length(seed_hex) == 1L && grepl("^[0-9a-f]{64}$", seed_hex), "Invalid draw seed.")
  selected <- integer(count); counter <- 0
  for (i in seq_len(count)) {
    total <- sum(pool$weight)
    bound <- 4294967296 - (4294967296 %% total)
    repeat {
      hex <- substr(fd_hash(paste0(seed_hex, ":", format(counter, scientific = FALSE, trim = TRUE))), 1L, 8L)
      counter <- counter + 1
      value <- strtoi(substr(hex, 1L, 4L), 16L) * 65536 + strtoi(substr(hex, 5L, 8L), 16L)
      if (value < bound) break
    }
    at <- which(cumsum(pool$weight) > (value %% total))[1L]
    selected[i] <- pool$row[at]
    pool <- pool[-at, , drop = FALSE]
  }
  selected
}
fd_make_record <- function(data, config, previous = character(), title = "Untitled draw") {
  snapshot <- list(columns = as.list(names(data)), rows = lapply(seq_len(nrow(data)), function(i) as.list(data[i, , drop = FALSE])),
    config = config, previous_ids = as.list(previous))
  snapshot_json <- fd_json(snapshot)
  pool <- fd_evaluate(data, config, previous)
  seed <- paste(sprintf("%02x", as.integer(openssl::rand_bytes(32))), collapse = "")
  selected <- fd_pick(pool[pool$eligible, , drop = FALSE], config$winners + config$alternates, seed)
  payload <- list(version = 1L, algorithm = FD_ALGORITHM, title = enc2utf8(title),
    created_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    snapshot_json = snapshot_json, snapshot_sha256 = fd_hash(snapshot_json),
    seed_hex = seed, selected_rows = as.list(selected))
  payload_json <- fd_json(payload)
  record <- list(format = "fairdraw-record-v1", sha256 = fd_hash(payload_json), payload_json = payload_json)
  fd_assert(nchar(fd_json(record), type = "bytes") <= FD_MAX_RECORD_BYTES,
    "The audit record exceeds 50 MB. Reduce the number of entries or columns.")
  record
}
fd_unpack <- function(record) {
  payload <- jsonlite::fromJSON(record$payload_json, simplifyVector = FALSE)
  snapshot <- jsonlite::fromJSON(payload$snapshot_json, simplifyVector = FALSE)
  columns <- unlist(snapshot$columns, use.names = FALSE)
  fd_assert(length(snapshot$rows) > 0L && length(snapshot$rows) <= FD_MAX_ROWS, "Invalid entry snapshot size.")
  fd_assert(length(columns) > 0L && length(columns) <= 200L && !anyDuplicated(columns), "Invalid snapshot columns.")
  values <- lapply(columns, function(col) vapply(snapshot$rows, function(row) {
    value <- row[[col]]
    fd_assert(is.character(value) && length(value) == 1L, "Snapshot values must be text.")
    value
  }, character(1)))
  names(values) <- columns
  data <- as.data.frame(values, stringsAsFactors = FALSE, check.names = FALSE)
  selected <- unlist(payload$selected_rows, use.names = FALSE)
  fd_assert(is.numeric(selected) && length(selected) > 0L && all(is.finite(selected)) &&
    all(selected == floor(selected) & selected >= 1 & selected <= nrow(data)) && !anyDuplicated(selected), "Invalid selected row indices.")
  list(payload = payload, snapshot = snapshot, data = data, config = snapshot$config,
    previous = unlist(snapshot$previous_ids, use.names = FALSE),
    selected = as.integer(selected))
}
fd_verify <- function(record) {
  fd_assert(is.list(record) && identical(record$format, "fairdraw-record-v1") &&
    is.character(record$payload_json) && length(record$payload_json) == 1L &&
    is.character(record$sha256) && length(record$sha256) == 1L, "This is not a Fairdraw JSON record.")
  fd_assert(identical(fd_hash(record$payload_json), record$sha256), "Record checksum does not match; the file has changed.")
  x <- fd_unpack(record)
  fd_assert(identical(x$payload$algorithm, FD_ALGORITHM) && isTRUE(x$payload$version == 1L), "Unsupported draw algorithm or version.")
  fd_assert(identical(fd_hash(x$payload$snapshot_json), x$payload$snapshot_sha256), "Entry snapshot checksum does not match.")
  fd_assert(x$config$match %in% c("all", "any"), "Invalid rule matching mode.")
  fd_assert(length(x$config$winners) == 1L && is.numeric(x$config$winners) && x$config$winners >= 1 && x$config$winners == floor(x$config$winners), "Invalid winner count.")
  fd_assert(length(x$config$alternates) == 1L && is.numeric(x$config$alternates) && x$config$alternates >= 0 && x$config$alternates == floor(x$config$alternates), "Invalid alternate count.")
  pool <- fd_evaluate(x$data, x$config, x$previous)
  replay <- fd_pick(pool[pool$eligible, , drop = FALSE], x$config$winners + x$config$alternates, x$payload$seed_hex)
  fd_assert(identical(as.integer(replay), x$selected), "Replayed winners do not match this record.")
  invisible(x)
}
fd_result_table <- function(record) {
  x <- fd_unpack(record); count <- length(x$selected)
  data.frame(Order = seq_len(count), Role = ifelse(seq_len(count) <= x$config$winners, "Winner", "Alternate"),
    ID = x$data[[x$config$id_field]][x$selected],
    Name = x$data[[x$config$label_field]][x$selected], stringsAsFactors = FALSE, check.names = FALSE)
}
fd_prior_winners <- function(records) {
  unique(unlist(lapply(records, function(record) {
    results <- fd_result_table(record); results$ID[results$Role == "Winner"]
  }), use.names = FALSE))
}
fd_sample <- function() {
  data.frame(ID = sprintf("P%03d", 1:24),
    Name = c("Sofia Novak", "Alex Chen", "Emma Fischer", "Oliver Svoboda", "Mia Rossi", "Noah Weber", "Isabella Horak", "Liam Martin", "Amelia Dvorak", "Lucas Silva", "Charlotte Klein", "Mateo Garcia", "Ella Dubois", "Ethan Novak", "Ava Kowalski", "Leo Andersson", "Lily Novak", "Oscar Schmidt", "Aria Novak", "Hugo Laurent", "Nora Meyer", "Adam Novak", "Freya Olsen", "Daniel Horak"),
    City = rep(c("Prague", "Berlin", "Vienna", "Brno", "Milan", "Paris"), 4),
    Membership = rep(c("Member", "Guest", "Member", "Premium", "Member", "Premium"), 4),
    Points = c(180, 80, 250, 310, 95, 210, 160, 40, 170, 280, 130, 220, 150, 90, 300, 100, 110, 185, 70, 230, 140, 60, 260, 205),
    Minimum_points = rep(c(100, 100, 150, 200), 6),
    Opted_in = rep(c("Yes", "No", "Yes", "Yes", "Yes", "Yes"), 4),
    Tickets = rep(c(1, 1, 2, 3, 1, 2), 4),
    Joined = format(as.Date("2026-01-01") + seq(0, 230, 10), "%Y-%m-%d"),
    stringsAsFactors = FALSE, check.names = FALSE)
}
fd_export_safe <- function(data) {
  # Neutralize spreadsheet formulas in user-provided text on CSV export.
  data[] <- lapply(data, function(x) {
    if (!is.character(x)) return(x)
    mask <- grepl("^[[:space:]]*[=+@-]", x)
    x[mask] <- paste0("'", x[mask]); x
  }); data
}
