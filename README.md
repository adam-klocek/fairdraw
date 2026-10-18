# Fairdraw — R Shiny winner picker

A complete R Shiny source project for choosing random winners from a list, with Excel input and contextual eligibility rules. The interface includes a searchable entry table, live exclusion reasons, a rule builder, a 30-second wheel reveal, draw history, and replayable JSON records. Czech and English are displayed together throughout the interface and certificate. Core interface text is at least 18 px, table headers at least 17 px, and primary controls have targets of at least 50 px, with strong emerald, gold, orange, and turquoise colors.

## Run

Requires R 4.1 or newer. Extract this project, open the `fairdraw-shiny` folder in RStudio, and run:

```r
source("install.R")       # Install missing dependencies once
shiny::runApp()           # Start the app
```

From a terminal in the project directory:

```bash
Rscript install.R
Rscript -e 'shiny::runApp(".", launch.browser = TRUE)'
```

The app starts with the supplied PDF export already loaded: 103 invoices in nine source columns. Invoice number is the default ID and customer name is the display field. No conditions are applied automatically. **Load sample** switches to the original 24-entry demonstration with 17 eligible entries. **Load supplied PDF data** restores the uploaded dataset.

## Excel and PDF workflow

1. Click **Import list → Excel workbook** and upload `.xlsx` or `.xls`.
2. Choose a worksheet. If the table starts below a title, set **Rows to skip before header**. Confirm whether the first remaining row is a header.
3. Review the worksheet preview, then click **Import entries**. Import replaces the current entries and clears conditions.
4. Choose the **Unique entry ID** and **Display name** columns. Add conditions using any other columns.
5. Select the number of winners and alternates, optionally select a weight column, and run the draw.

**PDF import:** choose **Import list → Export PDF / PDF export**, upload a text-based PDF matching the supplied invoice table, review its rows and total check, then confirm import. The parser reads all pages, removes repeated headers, preserves the nine columns, rejects unrecognized rows, and reconciles invoice amounts with the final `Celkem` total when present. It checks dates as well. Scans require OCR first and arbitrary PDF table layouts are not supported. If a file has no total line, that is clearly indicated rather than claiming a reconciliation. The supplied document has 103 invoices, 71 distinct customer IDs, and an amount total of 204,567.00. Names are retained as shown, including any truncation already present in the PDF.

The original file and the normalized startup data are stored under `data/`, outside the public `www/` directory. The source PDF is included so the native R importer can be tested against it. A fictional bilingual certificate design preview is available at `examples/certificate-preview.html`. Choosing **Číslo dokladu / Invoice number** gives a chance per invoice; choosing **Číslo zákazníka / Customer number** with duplicate removal gives a chance per customer, keeping the first invoice row before filtering. The app does not aggregate a customer's invoices or spending automatically.

**Download sample Excel workbook** in the import dialog produces a genuine `.xlsx` containing the sample participant table. Paste input also accepts one item per line, CSV, semicolon-separated data, or tab-separated cells copied directly from Excel.

Limits: 10 MB per Excel upload, 50 MB per audit JSON record, 50,000 entries, 200 columns, 30 conditions, 1–100 winners, and 0–100 alternates. Draws whose complete audit record would exceed 50 MB are blocked. Workbook import uses a worksheet rectangle; put headers in one row and one participant/item per row. It does not select Excel named tables separately. Duplicate or blank headers are rejected. Wholly empty rows are removed.

Store identifiers such as `00123` as **text cells in Excel**. Numeric cells with a custom leading-zero display format contain numbers; that formatting is not an ID. Dates guessed by readxl are normalized to `YYYY-MM-DD`. New draws also accept Czech `DD.MM.YYYY` dates and decimal-comma amounts such as `4 122,00` or `1.234,56` in conditions and imported data. US comma-grouped values such as `1,234.56` are rejected to avoid ambiguous parsing; plain `1234.56` is accepted. The optional **Read every column as text** setting helps with mixed-value columns; for date filtering, use ISO text or the default typed import. Formula values come from the workbook’s saved cached values; this app does not recalculate Excel formulas. Save in Excel before importing. Unencrypted workbooks are supported.

## Contextual conditions

The ID column identifies an entry; it does not restrict which columns can be filtered.

| Column | Condition | Compare with | Example |
| --- | --- | --- | --- |
| Opted_in | is | A value | `Yes` |
| City | is one of | A value | `Prague, Brno` |
| Points | is at least | A value | `100` |
| Points | is at least | Another column | `Minimum_points` |
| Joined | is before date | A value | `2026-10-01` |
| Email | is not empty | — | — |

Use **all conditions** for AND or **any condition** for OR. The initial version uses one group, without nested groups or quotas per category. Rules support equality, inequality, contains, does not contain, comma-separated membership, numeric comparisons, ISO/Czech date comparisons, and blank checks. New draw records store filter version 2. Original records without a filter version retain the original numeric and ISO-date matching rules on replay. The `is one of` operator takes a fixed comma-separated list. Text comparisons and ID matching ignore surrounding spaces and use Unicode lowercasing with an explicit English locale; they do not remove accents or alter internal spaces. Missing or nonnumeric values never pass numeric conditions; missing or invalid dates never pass date conditions. Before/after comparisons are strict.

Duplicate removal keeps the **first source occurrence before applying rules**. Thus a later duplicate does not replace an earlier ineligible occurrence. With duplicate removal off, each row is a separate chance and the same ID may win through multiple rows. Previous-winner exclusion compares normalized ID values across all records in the current session, so use the same ID namespace for related draws. Alternates are not treated as previous winners.

The entry table always explains exclusions. Its search, pagination, and status dropdown only change the view; they do not change the draw pool. **Export preview** exports the selected status view, including exclusion reasons and first-pick probabilities; it does not use the DataTables search query. Spreadsheet formula-like text is escaped in CSV exports. Source columns stay unchanged in the draw snapshot.

## Selection and records

Every draw generates a fresh 256-bit seed with `openssl::rand_bytes`. The engine hashes `seed_hex:counter` with SHA-256, takes an unsigned 32-bit value from the first eight hex digits, and uses rejection sampling to avoid modulo bias. It selects from cumulative integer weights and removes the selected row before the next selection. The first selected rows are winners; the remaining ordered rows are alternates. Equal weights give each eligible row the same chance. The total eligible weight must be at most 4,294,967,295.

The wheel and confetti are a **visual reveal**, after server-side selection. The wheel sectors do not represent entrants or weighted probabilities. **Instant reveal** and reduced-motion settings skip the animation. The standard wheel reveal lasts 30 seconds and includes a bilingual countdown and progress bar. **Skip animation**, **Instant reveal**, and the operating system reduced-motion preference can reveal immediately without changing the recorded result. Presentation mode can be closed with Escape.

Each audit record contains an exact JSON payload string, a SHA-256 checksum, the seed, and a snapshot of source entries, rules, settings, previous winners, and selected row indices. The nested JSON strings retain exact bytes for checksum verification after file transfers. Upload the exported JSON through **Verify a draw** to validate checksums, re-evaluate eligibility, and replay the selected row order. Verified records can be restored to session history.

The audit JSON contains the full participant list. **Results Excel** and the printable HTML **Certificate** include only selected entries, with winners and alternates labeled. The certificate is a self-contained Czech/English HTML document with an emerald-and-gold design, SVG shield seal, result table, record ID, Prague time, and checksum. It runs checksum and deterministic-replay verification again before generating the seal. The seal states **OVĚŘENO APLIKACÍ / APP VERIFIED**, not independent accreditation. Open the HTML certificate in a browser and print or save as PDF if needed. Certificate styles let large winner lists flow to further pages.

Records and certificates are self-issued. Checksums and deterministic replay establish internal consistency, **not independent certification, an externally trusted timestamp, or proof that the organizer did not rerun the draw**. Public immutable verification pages would require a separate persistent backend and external trust model. This project does not claim those features.

## Data, deployment, and scope

- Participant data, draw results, and history live in per-session Shiny reactive state. No application database is written. Ended sessions lose their state; export audit JSON to keep records and restore them later.
- Running locally processes uploaded workbooks in your local R process. Hosted Shiny processes files on that host, with separate state for each session. Temporary uploads follow Shiny’s lifecycle. Do not place participant files in `www/`, which is publicly served.
- The app has no registration or account login of its own. Hosting-level access controls can be added by your deployment platform. Google Fonts are optional external styling resources; offline use falls back to system fonts.
- Deploy this R project to **shinyapps.io**, **Posit Connect**, or an R-capable **Shiny Server**. A static website host cannot execute this app. No deployment credentials or hosting configuration are included.
- Direct social-comment retrieval, CRM integrations, video recording, persistent multi-user workspaces, nested rules, category quotas, and externally certified public records are not implemented. Exported comment or CRM tables can be imported through Excel or paste.

## Feature inspiration

The linked product pages were reviewed on 2026-10-18. Fairdraw adopts their useful workflow ideas while focusing on the requested list-and-conditions workflow.

| Inspiration | Useful idea adopted here |
| --- | --- |
| [RandomPicker](https://www.randompicker.com/giveaway-app/) | Winners plus alternates, entry weighting, duplicate review, and a draw snapshot |
| [AppSorteos](https://app-sorteos.com/en/apps/pick-random-name-winner) | Fast list input, filters, multiple winners, and a portable result summary |
| [Winner Wheel](https://apps.apple.com/us/app/winner-wheel-random-picker/id1605239546) | Wheel reveal, confetti, and presentation-friendly results |
| [Giveaway Picker](https://play.google.com/store/apps/details?id=com.of.giveawaypickerig) | Low-friction use without an application account; this implementation accepts exported tables rather than fetching social comments |
| [Easypromos](https://www.easypromosapp.com/pick-a-winner-app/) | Spreadsheet-based participant workflows and downloadable draw documentation |

Technical references: [Shiny file input](https://shiny.posit.co/r/components/inputs/file-input/), [readxl Excel import](https://readxl.tidyverse.org/reference/read_excel.html), [DT in Shiny](https://rstudio.github.io/DT/shiny.html), [Shiny dynamic UI](https://shiny.posit.co/r/articles/build/dynamic-ui/).

## Validation

Run the supplied focused import, filtering, random selection, replay, and Shiny server checks from the project root:

```bash
Rscript tests/run_tests.R
```

The tests include Excel worksheet discovery/import, leading-zero text IDs, missing values, ALL/ANY logic, column-to-column comparison, duplicates, previous winners, invalid dates/weights, exact independent selection vectors, a maximum 32-bit weight boundary, record round trips, tampering, and a Shiny server draw/reveal smoke check.

Optional animation checks require Node.js and no npm dependencies:

```bash
node --test tests/reveal.test.cjs
```

These four checks were executed successfully, covering the exact 30-second timer, skip idempotence, instant/reduced-motion behavior, and cancellation of old timers. The supplied PDF was independently extracted and reconciled, and a fictional certificate preview was rendered and visually reviewed.

On Linux, installing `pdftools` from source may require the OS package `libpoppler-cpp-dev`; Windows and macOS normally use CRAN binaries. See the [official pdftools installation guidance](https://docs.ropensci.org/pdftools/).

**Build-environment limitation:** R is not installed in the environment that produced this project. The R tests and browser interactions have not been executed there. Source delimiter checks, JavaScript syntax checks, independent algorithm-vector checks, and animation timer tests were performed; run the R suite before deploying. The native R PDF parser has not been executed in this environment; the PDF extraction/reconciliation check here used the equivalent layout-based parser and Poppler text extraction.

## Files

```text
app.R                 Shiny UI, session state, imports, downloads, verification
R/engine.R            Pure import, eligibility, deterministic selection, record functions
R/i18n.R              Czech/English labels without changing internal data keys
R/pdf_import.R        Strict parser for the supplied invoice PDF layout
R/certificate.R       Verified, escaped, bilingual HTML certificate rendering
templates/            Shared printable certificate HTML and SVG seal
data/                 Supplied PDF, parsed startup data, translations, import report
R/rule_module.R       Dynamic condition input modules
www/style.css         Base responsive interface
www/accessibility.css Large type, contrast, vivid colors, and mobile layout
www/app.js            Presentation mode and visual reveal
install.R             Dependency installer
run.R                 Local launch helper
tests/run_tests.R     Focused engine, PDF, certificate, and Shiny server checks
tests/reveal.test.cjs  Optional dependency-free Node animation timer tests
examples/entries.csv  Example participant table
```
