#!/usr/bin/env Rscript

# Development-only official-source inventory helper. This script is not run by
# package code or tests and is excluded from the built package with dev-docs/.

archive_replay <- function(url, timestamp = "20220603194616") {
  paste0("https://web.archive.org.au/awa/", timestamp, "mp_/", url)
}

clean_text <- function(x) {
  trimws(gsub("[[:space:]\u00a0]+", " ", as.character(x)))
}

read_page <- function(url) {
  if (file.exists(url)) {
    return(xml2::read_html(url))
  }
  destination <- tempfile("readreq-inventory-", fileext = ".html")
  on.exit(unlink(destination), add = TRUE)
  status <- system2(
    "curl",
    c("-L", "-sS", "--http1.1", "--retry", "3", "--max-time", "90",
      "-o", shQuote(destination), shQuote(url))
  )
  if (!identical(status, 0L) || !file.exists(destination)) {
    stop("Could not retrieve official page: ", url, call. = FALSE)
  }
  xml2::read_html(destination)
}

links <- function(doc) {
  nodes <- xml2::xml_find_all(doc, ".//a[@href]")
  data.frame(
    label = clean_text(xml2::xml_text(nodes)),
    href = xml2::xml_attr(nodes, "href"),
    stringsAsFactors = FALSE
  )
}

original_url <- function(x) {
  sub("^https?://web\\.archive\\.org\\.au/awa/[0-9]+[a-z_]+/", "", x)
}

absolute_replay_url <- function(x, base) {
  resolved <- xml2::url_absolute(x, base)
  if (grepl("^https?://web\\.archive\\.org\\.au/awa/", resolved)) {
    resolved <- gsub("https%3A", "https:", resolved, fixed = TRUE)
    return(sub("(_/https?):/(?!/)", "\\1://", resolved, perl = TRUE))
  }
  archive_replay(resolved)
}

identity <- function(x) {
  match <- regexec(
    "(?i)(march|june|september|december)[^0-9]{0,16}(20[0-9]{2})",
    x,
    perl = TRUE
  )
  pieces <- regmatches(x, match)[[1L]]
  if (length(pieces) != 3L) return(NULL)
  month <- c(march = 3L, june = 6L, september = 9L, december = 12L)[[
    tolower(pieces[[2L]])
  ]]
  list(
    release_id = sprintf("req-%s-%02d", pieces[[3L]], month),
    edition = tools::toTitleCase(tolower(pieces[[2L]])),
    year = as.integer(pieces[[3L]]),
    month = month
  )
}

role <- function(label, href) {
  value <- tolower(paste(label, href))
  if (grepl("\\.xlsx?([?#].*)?$", value)) {
    if (grepl("histor", value)) return("historical")
    if (grepl("forecast", value)) return("forecast")
  }
  if (grepl("\\.pdf([?#].*)?$", value) &&
      grepl("resources.{0,8}energy.{0,8}quarterly", value)) {
    return("report")
  }
  NA_character_
}

date_fields <- function(doc, id) {
  old_node <- xml2::xml_find_first(
    doc,
    ".//*[contains(@class,'field-name-field-date')]//*[@property='dc:date']"
  )
  old_content <- xml2::xml_attr(old_node, "content")
  old_text <- clean_text(xml2::xml_text(old_node))
  current_node <- xml2::xml_find_first(
    doc,
    paste0(
      ".//*[contains(@class,'field--name-field-date')]",
      "//*[contains(@class,'field__item')]"
    )
  )
  current_text <- clean_text(xml2::xml_text(current_node))
  candidates <- clean_text(c(old_content, old_text, current_text))
  candidates <- candidates[!is.na(candidates) & nzchar(candidates)]
  iso <- regmatches(
    candidates,
    regexpr("20[0-9]{2}-[0-9]{2}-[0-9]{2}", candidates)
  )
  iso <- iso[nzchar(iso)]
  if (length(iso)) {
    precision <- if (grepl(
      "^[A-Za-z]+ 20[0-9]{2}$",
      old_text
    )) "month" else "day"
    return(c(
      release_date = iso[[1L]],
      release_date_precision = precision
    ))
  }
  full_date <- regmatches(
    candidates,
    regexpr(
      "[0-9]{1,2} (January|February|March|April|May|June|July|August|September|October|November|December) 20[0-9]{2}",
      candidates,
      ignore.case = TRUE
    )
  )
  full_date <- full_date[nzchar(full_date)]
  if (length(full_date)) {
    parsed <- as.Date(full_date[[1L]], format = "%d %B %Y")
    return(c(
      release_date = format(parsed),
      release_date_precision = "day"
    ))
  }
  month_year <- paste(id$edition, id$year)
  c(
    release_date = sprintf("%04d-%02d-01", id$year, id$month),
    release_date_precision = if (any(grepl(month_year, candidates, ignore.case = TRUE))) {
      "month"
    } else {
      "edition"
    }
  )
}

asset_rows <- function(doc, page_url) {
  x <- links(doc)
  roles <- vapply(seq_len(nrow(x)), function(i) {
    role(x$label[[i]], x$href[[i]])
  }, character(1))
  keep <- !is.na(roles)
  data.frame(
    role = roles[keep],
    url = vapply(
      x$href[keep],
      if (grepl("^https?://web\\.archive\\.org\\.au/awa/", page_url)) {
        absolute_replay_url
      } else {
        xml2::url_absolute
      },
      character(1),
      base = page_url
    ),
    stringsAsFactors = FALSE
  )
}

inventory_page <- function(page_url, label) {
  id <- identity(paste(label, page_url))
  if (is.null(id)) return(NULL)
  doc <- read_page(page_url)
  assets <- asset_rows(doc, page_url)
  if (!any(assets$role %in% c("forecast", "historical"))) {
    candidates <- links(doc)
    candidates <- candidates[
      grepl("publications\\.industry\\.gov\\.au/publications/",
        candidates$href, ignore.case = TRUE
      ),
      ,
      drop = FALSE
    ]
    if (nrow(candidates)) {
      digital_url <- absolute_replay_url(candidates$href[[1L]], page_url)
      digital <- read_page(digital_url)
      assets <- rbind(assets, asset_rows(digital, digital_url))
    }
  }
  assets <- assets[!duplicated(assets$role), , drop = FALSE]
  dates <- date_fields(doc, id)
  pick <- function(x) {
    value <- assets$url[assets$role == x]
    if (length(value)) value[[1L]] else NA_character_
  }
  data.frame(
    release_id = id$release_id,
    release_date = unname(dates[["release_date"]]),
    release_date_precision = unname(dates[["release_date_precision"]]),
    edition = id$edition,
    cadence = "quarterly",
    landing_url = page_url,
    landing_source = if (grepl(
      "^https?://web\\.archive\\.org\\.au/awa/", page_url
    )) {
      "Australian Government Web Archive"
    } else {
      "Department of Industry, Science and Resources"
    },
    forecast_url = pick("forecast"),
    historical_url = pick("historical"),
    report_url = pick("report"),
    stringsAsFactors = FALSE
  )
}

archive_index <- read_page(
  archive_replay(
    "https://www.industry.gov.au/data-and-publications/resources-and-energy-quarterly"
  )
)
archive_links <- links(archive_index)
archive_links <- archive_links[
  grepl(
    "resources-and-energy-quarterly-(all/resources-and-energy-quarterly-)?(march|june|september|december)-20(1[3-9]|20)",
    archive_links$href,
    ignore.case = TRUE
  ),
  ,
  drop = FALSE
]
archive_links <- archive_links[
  !duplicated(vapply(
    seq_len(nrow(archive_links)),
    function(i) identity(paste(
      archive_links$label[[i]], archive_links$href[[i]]
    ))$release_id,
    character(1)
  )),
  ,
  drop = FALSE
]

current_index_url <- "https://www.industry.gov.au/publications/resources-and-energy-quarterly"
current_index <- read_page(if (file.exists("/tmp/readreq_index.html")) {
  "/tmp/readreq_index.html"
} else {
  current_index_url
})
current_links <- links(current_index)
current_links <- current_links[
  grepl(
    "/(data-and-)?publications/resources-and-energy-quarterly-(march|june|september|december)-20(2[1-6])",
    current_links$href,
    ignore.case = TRUE
  ),
  ,
  drop = FALSE
]

archive <- do.call(rbind, lapply(seq_len(nrow(archive_links)), function(i) {
  page_url <- absolute_replay_url(
    archive_links$href[[i]],
    archive_replay(
      "https://www.industry.gov.au/data-and-publications/resources-and-energy-quarterly"
    )
  )
  message("archive: ", archive_links$label[[i]])
  inventory_page(page_url, archive_links$label[[i]])
}))

current <- do.call(rbind, lapply(seq_len(nrow(current_links)), function(i) {
  page_url <- xml2::url_absolute(current_links$href[[i]], current_index_url)
  message("current: ", current_links$label[[i]])
  inventory_page(page_url, current_links$label[[i]])
}))

result <- rbind(archive, current)
result <- result[!duplicated(result$release_id, fromLast = TRUE), , drop = FALSE]
result <- result[order(result$release_id), , drop = FALSE]
utils::write.csv(result, "/tmp/readreq-release-inventory.csv", row.names = FALSE)
print(result, row.names = FALSE)
