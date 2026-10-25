# Getting started

## Choose an exact or moving release

Use `list_req_releases()` to inspect all 59 audited editions from September
2011 through June 2026. `"latest"` is convenient for exploration, while an
exact `release_id` pins a reproducible vintage.

```r
releases <- list_req_releases(supported_only = TRUE)
releases[c("release_id", "release_date", "support_status")]
stopifnot(nrow(releases) == 59)
```

## Download once, replay offline

```r
paths <- download_req_release(
  "req-2026-06",
  assets = c("forecast", "historical")
)

data <- read_req("req-2026-06", view = "current")
```

The raw cache is immutable. Repeating the exact request verifies and returns
the cached assets without redownloading them.

## Select the appropriate view

- `reported` preserves admitted source presentations.
- `canonical` is available from the asset-specific readers.
- `current` combines forecast and historical assets using the checked-in
  policy.

Use `reported` for audits and source reconciliation. Use `current` when one
policy-controlled value per observation is required.

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
