# Generate reduced/derived synthetic REQ workbook fixtures.
#
# These workbooks reproduce structural parser paths only. They contain no
# official workbook values, logos, decorative material, or third-party data.

if (!requireNamespace("writexl", quietly = TRUE)) {
  stop("The fixture generator requires the suggested writexl package.")
}

catalogue <- utils::read.csv(
  file.path("inst", "catalogue", "source-catalog.csv"),
  stringsAsFactors = FALSE
)
fixture_dir <- file.path("tests", "testthat", "fixtures", "workbooks")
dir.create(fixture_dir, recursive = TRUE, showWarnings = FALSE)

metadata_sheet <- function(text) {
  data.frame(metadata = c(text, "Synthetic reduced fixture"), check.names = FALSE)
}

wide_sheet <- function(table_id) {
  out <- data.frame(
    label = c(
      "World", "Synthetic series a", "Synthetic missing",
      "Notes:", "a Synthetic definition.",
      "Sources: Synthetic provider; Third-party synthetic label."
    ),
    unit = c("", "kt", "kt", "", "", ""),
    `2024` = c("", "10", "na", "", "", ""),
    `2025 s` = c("", "11", "na", "", "", ""),
    `2026 f` = c("", "12", "na", "", "", ""),
    `2027 z` = c("", "13", "na", "", "", ""),
    check.names = FALSE
  )
  names(out)[[1]] <- table_id
  out
}

monthly_sheet <- function(table_id) {
  out <- data.frame(
    date = c("", "2025-01-31", "2025-02-28", "2025-03-31", "", ""),
    `Synthetic benchmark` = c(
      "US$/t", "10", "11", "12", "Notes:",
      "Sources: Synthetic provider; Third-party synthetic label."
    ),
    `Synthetic missing` = c("US$/t", "na", "12", "13", "", ""),
    check.names = FALSE
  )
  # writexl writes dates as true Excel dates when supplied as Date.
  out$date <- c(
    NA, as.Date("2025-01-31"), as.Date("2025-02-28"),
    as.Date("2025-03-31"), NA, NA
  )
  out
}

make_workbook <- function(source_dataset, shuffled = FALSE) {
  cat_rows <- catalogue[catalogue$source_dataset == source_dataset, ]
  sheets <- lapply(seq_len(nrow(cat_rows)), function(i) {
    row <- cat_rows[i, ]
    if (row$classification == "metadata") {
      text <- if (row$source_label == "About" && source_dataset == "historical") {
        "Resources and Energy Quarterly, June 2025."
      } else {
        paste("Synthetic", row$source_label)
      }
      metadata_sheet(text)
    } else if (row$parser_family == "history_monthly") {
      monthly_sheet(row$table_id)
    } else {
      wide_sheet(row$table_id)
    }
  })
  names(sheets) <- cat_rows$source_label
  names(sheets)[names(sheets) == "Australia quarterly export values"] <-
    "Quarterly export values"
  names(sheets)[names(sheets) == "Steel-making metallurgical coal"] <-
    "Steel-making met coal"
  if (shuffled) sheets <- sheets[rev(seq_along(sheets))]
  sheets
}

writexl::write_xlsx(
  make_workbook("forecast"),
  file.path(fixture_dir, "forecast-all-families.xlsx")
)
writexl::write_xlsx(
  make_workbook("forecast", shuffled = TRUE),
  file.path(fixture_dir, "forecast-shuffled.xlsx")
)
unmapped <- make_workbook("forecast")
unmapped[["World macro"]][["Unmapped payload"]] <- c(
  "", "999", "", "", "", ""
)
writexl::write_xlsx(
  unmapped,
  file.path(fixture_dir, "forecast-unmapped-numeric.xlsx")
)
unmapped[["World macro"]][["Unmapped payload"]][[2]] <- "na"
writexl::write_xlsx(
  unmapped,
  file.path(fixture_dir, "forecast-unmapped-marker.xlsx")
)
writexl::write_xlsx(
  make_workbook("historical"),
  file.path(fixture_dir, "historical-all-families-wrong-about.xlsx")
)

message("Generated reduced synthetic workbook fixtures in ", fixture_dir)
