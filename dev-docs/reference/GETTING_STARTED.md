# Getting started

## Choose an exact or installed-latest release

REQ itself begins with September 2011. Use `list_req_releases()` to inspect all
59 audited editions from then through June 2026: September and December 2011,
every quarter in 2012--2025, and June 2026. Earlier ABARE/ABARES products are
predecessors rather than missing REQ editions. Historical tables can contain
observations from 2000 or earlier, with series-specific start and end periods.
`"latest"` selects the newest row in the installed catalogue and can move only
when that package/catalogue is updated; an exact `release_id` pins a
reproducible vintage.

```r
releases <- list_req_releases(supported_only = TRUE)
releases[c("release_id", "release_date", "support_status")]
stopifnot(nrow(releases) == 59)
```

## First read, entirely offline

The installed package includes a reduced synthetic forecast workbook that
exercises the real parser without network access or official observations:

```r
fixture <- system.file(
  "extdata", "readreq-example-forecast.xlsx", package = "readreq"
)
example <- read_req_forecasts(fixture, cache_dir = tempdir())
stopifnot(ncol(example) == 35L)
```

## Download once, replay offline

```r
paths <- download_req_release(
  "req-2026-06",
  assets = c("forecast", "historical")
)

data <- read_req("req-2026-06", view = "current")
```

For catalogue release IDs, this retrieval uses the bundled HTTPS URLs. The raw
cache is immutable. Repeating the exact request verifies and returns
the cached assets without redownloading them.

## Select the appropriate view

- `reported` preserves admitted source presentations.
- `canonical` is available from the asset-specific readers.
- `current` combines forecast and historical assets using the checked-in
  policy.

Use `reported` for audits and source reconciliation. Use `current` when one
policy-controlled value per observation is required, after confirming that
its `conflicts` attribute contains no unresolved rows.

## Filter at the reader

```r
iron_ore <- read_req_forecasts(
  "req-2026-06",
  commodities = "Iron ore",
  view = "canonical"
)

monthly <- read_req_history(
  "req-2026-06",
  frequency = "monthly",
  view = "canonical"
)
```

Filtering is deterministic. It does not change series identity or permit
unclassified cells to be ignored.

## Validate before publishing results

```r
report <- validate_req_release("req-2026-06")
stopifnot(report$valid)
```

Persist the release ID, source hashes and package version with any derived
output. Use `req_attribution()` when publishing results.
