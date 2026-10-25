# readreq

`readreq` reads the complete official history of the Australian Government's
[Resources and Energy Quarterly](https://www.industry.gov.au/publications/resources-and-energy-quarterly)
(REQ), from the inaugural September 2011 edition through June 2026.

The package provides 59 audited editions:

- 57 editions with their complete structured forecast and historical workbook
  tables;
- December 2011 and March 2013 with audited Key macroeconomic assumptions from
  their official reports; and
- exact release metadata, source hashes, parser provenance and validation
  results for every edition.

## Installation

Build and install from a local clone:

```sh
R CMD build .
R CMD INSTALL readreq_0.1.0.tar.gz
```

## Read the complete release history

```r
library(readreq)

releases <- list_req_releases()
nrow(releases)
#> 59

first_release <- read_req("req-2011-09", view = "reported")
latest_release <- read_req("latest", view = "current")
```

`list_req_releases()` returns the audited static catalogue in release order.
Every entry resolves to exact official assets and can be downloaded, cached,
parsed and validated with the same public API.

```r
download_req_release("req-2017-03")
validation <- validate_req_release("req-2017-03")
stopifnot(validation$valid)

reported <- read_req("req-2017-03", view = "reported")
current <- read_req("req-2017-03", view = "current")
series <- req_series_catalog("req-2017-03")
```

The two report-backed editions expose the audited macroeconomic table through
the same reader:

```r
december_2011 <- read_req("req-2011-12", view = "reported")
unique(december_2011$table_id)
#> "report_key_macroeconomic_assumptions"
```

Local forecast and historical workbooks can also be parsed directly:

```r
forecast <- read_req_forecasts("/path/to/forecast-data.xlsx")
history <- read_req_history("/path/to/historical-data.xlsx")
```

## Data contract

Each observation carries its release, source asset and sheet, semantic table,
period, status, unit, source note, retrieval time, SHA-256 hash and parser
version.

- `series_id` identifies a semantic series across target periods and vintages.
- `observation_key` combines `series_id` and target period.
- `record_role` identifies reported, canonical and current records.
- `source_dataset` records workbook or report provenance.

Source missing, confidential and suppressed values remain numeric `NA` with an
explicit `missing_reason`.

## Vintages and revisions

The package keeps historical revisions, forecast revisions and forecast errors
as distinct analytical operations:

```r
req_history_revision(data)
req_forecast_revision(data)
req_forecast_error(data, realisation = "first")

compare_req_vintages(
  releases = c("req-2025-12", "req-2026-06"),
  comparison = "forecast_revision"
)
```

## Reproducible cache

Official assets are stored in an immutable content-addressed cache. Parsed
cache keys include the source hash, parser version, asset and selection. An
exact edition remains reproducible offline after its assets have been cached.

Installed API documentation is available through:

```r
help(package = "readreq")
```
