# `readreq` package implementation plan

Status: archived initial design; superseded by
`../reference/SUPPORTED_RELEASES.md` and the 59-edition certification
Prepared: 2026-07-27
Primary source: [Resources and Energy Quarterly](https://www.industry.gov.au/publications/resources-and-energy-quarterly)
Downstream consumer: Chartwell (`/path/to/user/dev/data_viewer`)

## 1. Executive decision

Build `readreq` as a small, standalone R package for discovering, downloading, snapshotting, parsing and comparing Resources and Energy Quarterly releases.

Every release is a three-asset bundle:

1. forecast-data workbook;
2. historical-data workbook; and
3. report PDF.

The package must parse the two Excel workbooks and retain the PDF for narrative, definitions and validation. It must cover every published sheet, not only headline export earnings or a short list of commodities.

The app's default request will be the latest coherent view. The package must also retain every exact release so consumers can distinguish:

- revisions to published history;
- revisions to estimates;
- revisions to forecasts and projections;
- status transitions;
- first-realisation forecast errors; and
- later revisions to the realised value.

No maintained purpose-built R client was found. `readreq` therefore owns both source transport and source-specific parsing, using shared design conventions that can later be reused by other workbook packages.

## 2. Evidence baseline

The initial source audit covered a nine-release 2024–2026 milestone:

- March, June, September and December 2024;
- March, June, September and December 2025; and
- June 2026.

The official index does not list a March 2026 release. Release discovery must not manufacture an expected quarterly edition.

Observed conditions:

- Every audited forecast workbook has 23 sheets.
- Every audited historical workbook has 47 sheets.
- Sheet order changes across releases.
- Forecast sheet widths change materially.
- Hidden/control metadata columns appear and disappear.
- The `About` and `Contents` sheets swap order in some releases.
- The quarterly export value, price and volume sheets change order.
- Historical sheets may appear out of numeric order.
- The June 2026 historical workbook incorrectly identifies itself as June 2025 on the `About` sheet.
- Releases use mixed calendar-year, financial-year, quarterly and monthly periods.
- Status markers include `s` for estimate, `f` for forecast and `z` for projection.
- Values mix nominal and real bases, Australian and US currencies, physical units and percentage rates.
- Literal missing-value markers such as `na` occur in data regions.
- Nested headers, merged cells, footnote codes and world/Australia sections are common.

The official landing page and downloaded content hash—not an internal workbook title—must be the authoritative release identity.

One audited revision sequence is a required golden test:

| Release | Target | Series | Published value |
|---|---|---|---:|
| December 2025 | 2025–26 | Resources and energy export value | A$382,959.866 million |
| June 2026 | 2025–26 | Resources and energy export value | A$404,920.368 million |

The comparison must retain each release's period/status label and provenance rather than treating the second value as an overwrite.

## 3. Package objective

Provide a stable, source-faithful R interface over the complete REQ workbook surface.

The package succeeds when a consumer can:

1. enumerate actual official releases and their three assets;
2. retrieve an exact release reproducibly;
3. inspect the available series without manually opening Excel;
4. parse all forecast and historical sheets;
5. distinguish commodity, concept, geography, frequency, period basis, status, unit, currency and price basis;
6. request a coherent latest view without losing source-dataset provenance;
7. compare the same observation across vintages; and
8. reproduce a result offline from immutable raw assets.

## 4. Scope

### 4.1 In scope for version 0.1.0

- Official release-index and release-page discovery.
- Forecast workbook, historical workbook and PDF retrieval.
- Release-page identity, asset hashes and immutable snapshots.
- All 23 forecast workbook sheets.
- All 47 historical workbook sheets.
- Stable semantic series and observation keys.
- A source-faithful reported view.
- A documented current/canonical stitching policy.
- Calendar-year, financial-year, quarter and month parsing.
- Estimate, forecast and projection status.
- Nominal/real, price basis, currency and physical-unit metadata.
- Missing, confidential or unavailable value preservation.
- Historical revision, forecast revision and forecast-error helpers.
- Offline fixtures, schema contracts, validation reports and opt-in live tests.
- Package documentation and manager handoff evidence.

### 4.2 Initial release coverage (superseded)

The initial plan targeted nine 2024–2026 releases. Version 0.1.0 now supports
all 59 actual editions from September 2011 through June 2026.

The discovery layer should also enumerate official 2021–2023 pages where the current index exposes them. Parsing those releases can be admitted into the supported set once they pass the same fixture and validation contract.

Legacy editions were subsequently admitted after their exact assets and
outputs passed the same audit.

### 4.3 Deferred

- OCR or PDF table extraction.
- Interactive Power BI retrieval.
- Resources and Energy Major Projects reports.
- Mine- or company-level project databases.
- Licensed price histories not contained in the official workbooks.
- Forecast modelling or scenario generation.
- Chartwell provider registration, search UI and chart definitions.
- CRAN submission before at least two post-implementation releases have been processed.

### 4.4 Explicit non-goals

- Do not assume a release exists because a quarter has ended.
- Do not trust the internal `About` date over the official release page.
- Do not identify a sheet by workbook position.
- Do not join forecast and historical workbooks by row or column position.
- Do not infer status solely from the target period's relation to the release date.
- Do not replace literal `na`, suppressed or unavailable values with zero.
- Do not silently collapse nominal and real series.
- Do not silently convert calendar-year values into financial-year values.
- Do not discard world-market series because the first consumer is Australian.

## 5. Repository and delivery model

Create `readreq` as a standalone R package repository adjacent to the Chartwell repository.

Initial delivery:

- begin at `0.0.0.9000`;
- install into Chartwell only by pinned commit;
- tag `v0.1.0` after all quality gates pass;
- use semantic versioning after the first stable release;
- maintain a machine-readable parser-profile version separately from package version where necessary.

Package implementation must not be placed in `data_viewer/R`. The eventual app adapter is a separate downstream project.

## 6. Public API

### 6.1 Release discovery

```r
list_req_releases(
  refresh = FALSE,
  supported_only = FALSE,
  cache_dir = req_cache_dir()
)
```

Returns actual official releases. Required fields:

- `release_id`;
- `release_date`;
- `edition`;
- `landing_url`;
- `forecast_url`;
- `historical_url`;
- `report_url`;
- asset availability;
- support status;
- `discovered_at`; and
- warnings.

A stable release ID should resemble `req-2026-06`, while the exact official publication date remains a separate field.

### 6.2 Bundle retrieval

```r
download_req_release(
  release = "latest",
  assets = c("forecast", "historical", "report"),
  cache_dir = req_cache_dir(),
  refresh = FALSE,
  verify = TRUE
)
```

Requirements:

- resolve `latest` once;
- perform atomic downloads;
- calculate SHA-256;
- retain HTTP metadata;
- reject HTML/error payloads;
- validate workbook readability;
- preserve an existing exact snapshot;
- return a raw-asset manifest.

### 6.3 Forecast data

```r
read_req_forecasts(
  release = "latest",
  sheets = "all",
  commodities = NULL,
  concepts = NULL,
  geography = NULL,
  view = c("canonical", "reported"),
  cache_dir = req_cache_dir(),
  refresh = FALSE
)
```

This must parse all forecast sheets by default. `sheets` accepts stable semantic IDs and documented source aliases.

### 6.4 Historical data

```r
read_req_history(
  release = "latest",
  tables = "all",
  commodities = NULL,
  concepts = NULL,
  geography = NULL,
  frequency = NULL,
  view = c("canonical", "reported"),
  cache_dir = req_cache_dir(),
  refresh = FALSE
)
```

This must parse all historical table families by default.

### 6.5 Combined current view

```r
read_req(
  release = "latest",
  data = c("all", "history", "forecast"),
  view = c("current", "reported"),
  cache_dir = req_cache_dir(),
  refresh = FALSE
)
```

Rules:

- `view = "reported"` returns all records from both workbooks.
- `view = "current"` applies a checked-in stitching manifest.
- Every returned row still identifies `source_dataset`.
- A collision the manifest cannot resolve is an error or explicit conflict row, never an arbitrary last-row win.

### 6.6 Series catalogue

```r
req_series_catalog(
  release = "latest",
  data = c("all", "history", "forecast"),
  cache_dir = req_cache_dir()
)
```

Returns distinct semantic series and their available period range without returning the full observation payload. This is the intended downstream search/discovery seam.

### 6.7 Vintage comparison

```r
compare_req_vintages(
  data = NULL,
  releases = NULL,
  series = NULL,
  comparison = c("all", "history_revision", "forecast_revision", "forecast_error"),
  cache_dir = req_cache_dir()
)
```

### 6.8 Supporting API

Export only if reused:

```r
req_cache_dir()
req_attribution()
validate_req_release()
```

Keep individual sheet parsers internal.

## 7. Data contracts

### 7.1 Release manifest

| Field | Meaning |
|---|---|
| `release_id` | Stable package release identifier |
| `release_date` | Official landing-page publication date |
| `edition` | March, June, September or December label |
| `landing_url` | Official release page |
| `forecast_url` | Forecast workbook |
| `historical_url` | Historical workbook |
| `report_url` | Report PDF |
| `asset_status` | Complete, partial or invalid |
| `support_status` | Supported, discovered-unverified or unsupported |
| `discovered_at` | UTC timestamp |
| `discovery_version` | Discovery/parser version |
| `warning` | Source anomaly, including missing expected editions |

The release manifest records what exists. It must not fill quarterly gaps.

### 7.2 Raw asset manifest

| Field | Meaning |
|---|---|
| `release_id` | Parent release |
| `asset_type` | Forecast, historical or report |
| `source_url` | Exact official URL |
| `source_filename` | Link/server filename |
| `detected_format` | XLSX, XLS, PDF or unknown |
| `content_type` | HTTP content type |
| `retrieved_at` | UTC timestamp |
| `etag` / `last_modified` | Server metadata where available |
| `sha256` | Content hash |
| `bytes` | File size |
| `local_path` | Cache location |
| `validation_status` | Valid, warning or rejected |

### 7.3 Observation schema

Every observation from either workbook must expose:

| Field | Rule |
|---|---|
| `release_id` | Exact REQ vintage |
| `release_date` | Official page date |
| `source_dataset` | `historical` or `forecast` |
| `source_sheet` | Actual workbook sheet label |
| `table_id` | Stable semantic sheet/table ID |
| `table_title` | Published title |
| `section` | World, Australia, state/territory, export destination or other published section |
| `commodity` | Normalised commodity or sector |
| `concept` | Production, consumption, stocks, trade, exports, imports, price, value, employment, investment or a more specific published concept |
| `geography` | Published geography |
| `frequency` | Annual, quarterly or monthly |
| `period` | Normalised target period |
| `period_start` / `period_end` | Parsed dates where defensible |
| `period_basis` | Calendar year, Australian financial year, calendar quarter, month, Japanese fiscal year or another explicit basis |
| `period_status` | Historical, estimate, forecast, projection or published-unclassified |
| `status_source` | Suffix, title, note, landing-page metadata or unclassified |
| `price_basis` | Nominal, real, unit value, spot, contract, benchmark or not applicable |
| `currency` | AUD, USD or other explicit currency |
| `unit` | Normalised published unit |
| `value` | Numeric value |
| `raw_value` | Original cell value |
| `missing_reason` | Provider `na`, suppressed, unavailable, blank or not applicable |
| `footnote_codes` | Published codes |
| `source_note` | Relevant source/definition note |
| `record_role` | Canonical or supporting presentation |
| `series_id` | Deterministic semantic key |
| `observation_key` | `series_id` plus target period |
| `retrieved_at` | Asset retrieval time |
| `sha256` | Source asset hash |
| `parser_version` | Package/parser profile |

Do not combine values with different period basis, status, price basis, currency or unit into one `series_id`.

### 7.4 Status rules

Status precedence:

1. explicit suffix in the workbook period label;
2. explicit row/column header;
3. explicit sheet note or legend;
4. explicit release-page description;
5. otherwise `published-unclassified`.

Required suffix mappings:

- `s` → `estimate`;
- `f` → `forecast`;
- `z` → `projection`.

If the landing page describes a value as estimated but the workbook period is unmarked, retain `status_source = "landing-page"` and the source text used. Never make the inference from date position alone.

### 7.5 Missing-value rules

Map provider markers to `value = NA_real_` while preserving:

- `raw_value`;
- `missing_reason`; and
- any footnote or confidentiality note.

At minimum distinguish:

- blank cell;
- literal `na`;
- not applicable;
- not available;
- confidential/suppressed; and
- parse failure.

A parse failure is an error, not a normal missing value.

## 8. Source inventory and semantic catalogue

Maintain a checked-in semantic catalogue with stable IDs, source-title patterns, parser family and expected dimensions.

### 8.1 Forecast workbook

The current 23-sheet inventory is:

1. `Contents`;
2. `About`;
3. World macro;
4. Australia macro;
5. Commodity sector;
6. Selected exports;
7. Australia's quarterly export values;
8. Quarterly prices;
9. Quarterly export volumes;
10. Steel-making;
11. Steel-making — steel;
12. Steel-making — iron ore;
13. Steel-making — metallurgical coal;
14. Thermal coal;
15. Oil;
16. Gas;
17. Uranium;
18. Gold;
19. Aluminium;
20. Copper;
21. Nickel;
22. Zinc; and
23. Lithium.

Sheet order is not stable. Match by normalised title and structural fingerprint.

### 8.2 Historical workbook

Metadata sheets:

- `Contents`;
- `Data directory`;
- `About`.

Data-table families:

| Tables | Family |
|---|---|
| 1–4 | Annual Australian export volume, export value, unit value and imports |
| 5–7 | Annual Australian production and world prices/production/consumption/stocks/trade |
| 8–14 | Annual/quarterly GVA, employment, income, lending, capital expenditure and exploration |
| 15–20 | Quarterly production, exports, imports and exploration |
| 21–22 | Monthly export unit values and benchmark prices |
| 23–37 | Commodity detail: aluminium, coal, copper, gemstones, gold, iron ore/steel, lead, lithium, nickel, petroleum, phosphate, silver, tin, uranium and zinc |
| 38–41 | Principal export markets by value/volume and financial/calendar year |

Use semantic IDs such as:

```text
annual_export_volume
annual_export_value
annual_production
quarterly_production
monthly_benchmark_prices
commodity_lithium
export_markets_value_fy
```

Table numbers remain provenance only.

## 9. Parser families

### 9.1 Forecast overview parser

For:

- world macro;
- Australia macro;
- commodity sector;
- selected exports.

Handle:

- sparse control columns;
- multiple header rows;
- calendar and financial years;
- nominal and real rows;
- annual percentage changes and CAGR columns;
- estimate/forecast/projection suffixes.

### 9.2 Forecast quarterly parser

For quarterly values, prices and volumes.

Handle:

- Excel date serials and formatted text dates;
- historical, estimate, forecast and projection horizons;
- nominal/value/volume distinctions;
- commodity-specific units;
- column order changes.

### 9.3 Commodity forecast parser

Use one common engine plus commodity-specific profiles.

The engine must recognise:

- world and Australian sections;
- production, consumption, stocks and trade;
- Australian mine/refinery/output concepts;
- export volumes, values and unit values;
- nominal and real prices;
- physical-content versus gross-weight measures;
- calendar versus financial-year blocks;
- multiple products within a sheet, such as bauxite/alumina/aluminium or crude/condensate/LPG.

Commodity profiles should provide aliases, section boundaries, unit corrections and known footnote semantics without hard-coding cell coordinates as the sole locator.

### 9.4 Historical annual parser

For Tables 1–14.

Support wide commodity columns, long time histories, nested units and multiple economic concepts.

### 9.5 Historical quarterly parser

For Tables 15–20.

Parse Excel serial dates explicitly and retain quarter-end/reference-period semantics.

### 9.6 Historical monthly parser

For Tables 21–22.

Retain monthly frequency and price/unit-value basis. Do not aggregate in the parser.

### 9.7 Historical commodity-detail parser

For Tables 23–37.

Use commodity-specific profiles where table structures genuinely differ. Do not force unrelated sheets into a misleading universal layout if that would lose published dimensions.

### 9.8 Export-market parser

For Tables 38–41.

Preserve:

- destination geography;
- commodity;
- value or volume;
- calendar or financial-year basis;
- unit and currency.

## 10. Current/canonical stitching policy

The reported view always returns both workbooks without destructive deduplication.

The current view must use a versioned precedence manifest.

Initial policy:

1. use the historical workbook for completed historical periods where it publishes the required series;
2. use the forecast workbook for explicit estimates, forecasts and projections;
3. retain forecast-workbook values for concepts absent from the historical workbook;
4. retain historical-workbook values for detailed histories absent from the forecast workbook;
5. preserve source-dataset identity on every chosen row;
6. never combine nominal and real rows;
7. never combine calendar and financial years;
8. when equivalent unmarked observations conflict and no source rule resolves them, return a conflict instead of choosing by file order.

The manifest should record:

- semantic series family;
- source priority by status;
- effective release range;
- reason;
- test fixture proving the choice.

## 11. Parser architecture

Use explicit layers:

```text
release index discovery
    ↓
release page and asset roles
    ↓
immutable asset cache
    ↓
workbook/sheet catalogue
    ↓
parser family + release profile
    ↓
normalisation and semantic keys
    ↓
reported or current view
    ↓
vintage comparisons
```

Recommended internal modules:

- `release-discovery.R`
- `download.R`
- `cache.R`
- `workbook-catalog.R`
- `parse-forecast-overview.R`
- `parse-forecast-quarterly.R`
- `parse-forecast-commodity.R`
- `parse-history-annual.R`
- `parse-history-quarterly.R`
- `parse-history-monthly.R`
- `parse-history-commodity.R`
- `parse-history-markets.R`
- `profiles-forecast.R`
- `profiles-history.R`
- `normalise-period.R`
- `normalise-status.R`
- `normalise-series.R`
- `stitch-current.R`
- `vintages.R`
- `validation.R`
- `conditions.R`

All parsers accept local files plus release metadata and perform no network calls.

## 12. Release profiles and schema drift

Use structural fingerprints and explicit release profiles.

A fingerprint may include:

- normalised sheet title;
- recognised table title;
- number and content of header rows;
- key row labels;
- unit column position by label;
- period-label pattern;
- section labels;
- note/legend markers.

Do not use row count or column count as the only fingerprint.

Profiles should cover at least:

- March 2024 narrow forecast layout;
- June/September/December 2024 layouts;
- March 2025 long-horizon layout;
- June 2025 compressed overview layout;
- September/December 2025 layout;
- June 2026 five-year outlook layout;
- June 2026 historical workbook with incorrect internal edition metadata.

Unknown fingerprints must fail with a typed schema error and a diagnostic summary.

## 13. File and cache behavior

Use `tools::R_user_dir("readreq", "cache")` by default and accept an explicit cache directory.

Recommended layout:

```text
cache/
  discovery/
    releases.json
  raw/
    <release_id>/
      <sha256>/
        forecast.xlsx
        historical.xlsx
        report.pdf
        asset-manifest.json
  parsed/
    <release_id>/
      <parser-version>/
        forecast.rds
        historical.rds
        current.rds
        validation.rds
```

Requirements:

- atomic writes;
- safe concurrent readers and one writer;
- cache keys include release, hash, parser version and view;
- exact-release raw snapshots are immutable;
- discovery refresh never deletes raw assets;
- supplied local paths work offline;
- parsed caches are invalidated by parser-version changes;
- pruning is explicit and scoped.

## 14. Revision and forecast-error model

Use:

- `series_id`: all semantic dimensions except target period and vintage;
- `observation_key`: `series_id` + target period.

### 14.1 History revision

Compare the same historical observation across releases.

Return:

- releases and source hashes;
- old/new value;
- absolute and percentage change where valid;
- status and status source;
- source dataset/sheet;
- whether the revision changed nominal/real or unit metadata.

A metadata change that makes values non-comparable must be a flagged break, not a numeric revision.

### 14.2 Forecast revision

Compare the same target period where the earlier value is a forecast or projection.

Retain:

- issue date;
- target period;
- horizon;
- status transition;
- absolute and percentage revision;
- currency, unit and price basis.

### 14.3 Forecast error

Compare a prior forecast with the first later estimate or historical observation for the same semantic key.

Offer a separate `latest_revised_error` when comparing with the newest historical value. Never label the latest revised error as the original forecast error.

### 14.4 Cross-workbook rules

Forecast-to-realisation matching may cross from forecast workbook to historical workbook only when:

- `series_id` semantics match;
- units and price basis match;
- period basis matches;
- geography matches;
- no structural-break flag applies.

## 15. Error and warning contract

Typed conditions:

- `req_release_discovery_error`;
- `req_release_gap_warning`;
- `req_asset_missing_error`;
- `req_download_error`;
- `req_asset_format_error`;
- `req_workbook_schema_error`;
- `req_sheet_parse_error`;
- `req_period_parse_error`;
- `req_unit_conflict_error`;
- `req_stitch_conflict_error`;
- `req_validation_error`.

Every error should include release ID, asset, sheet/table and remediation context.

Fail loudly when:

- a required workbook is absent;
- a download is not the expected type;
- a known sheet cannot be mapped semantically;
- a required unit or period header is unresolved;
- non-empty values would be dropped;
- a current-view collision is unresolved;
- a vintage join is non-unique;
- currency, price basis or period basis changes within one semantic series without an explicit break.

Warn, while retaining provenance, for:

- an expected quarterly release gap;
- incorrect internal workbook edition metadata;
- new non-data sheets;
- a known optional section that is absent;
- a newly observed but explicitly preserved missing-value marker.

## 16. Dependencies

Proposed imports:

- `cli`;
- `digest`;
- `fs`;
- `httr2`;
- `readxl`;
- `rlang`;
- `rvest`;
- `stringr`;
- `tibble`;
- `vctrs`; and
- `xml2`.

Proposed suggests:

- `testthat` (>= 3.0.0);
- `withr`;
- `webfakes`;
- `waldo`;
- `knitr`; and
- `rmarkdown`.

Avoid mandatory database, Arrow, geospatial or Java dependencies. Add another runtime dependency only with a measured reduction in code or failure risk.

## 17. Test and fixture strategy

### 17.1 Offline default

The default suite performs no live network requests.

Fixtures:

- release index HTML;
- representative release pages;
- reduced but structurally faithful XLSX workbooks;
- incorrect `About` date fixture;
- shuffled sheet-order fixture;
- hidden/control-column fixture;
- literal `na` and confidentiality marker fixture;
- malformed headers and incompatible unit fixtures;
- transport error and HTML-as-XLSX fixtures.

Mock transport, not parser behavior.

### 17.2 Representative release matrix

At minimum:

| Release | Required behavior |
|---|---|
| March 2024 | Older narrow forecast workbook and legacy filenames |
| December 2024 | Two-year forecast layout |
| March 2025 | Longer forecast/projection horizon |
| June 2025 | Compressed overview width and sheet-order variant |
| September 2025 | Quarterly-sheet order change |
| December 2025 | Pre-June forecast baseline |
| June 2026 | Five-year outlook and incorrect historical `About` date |

Retain checksums for all 59 audited edition bundles in development evidence
even though official workbook bytes are not committed.

### 17.3 Required test groups

- Release discovery and gap preservation.
- Release-page asset extraction.
- Asset download, hashing and idempotency.
- Workbook and sheet semantic catalogue.
- Every forecast parser family.
- Every historical parser family.
- All 15 commodity detail/forecast families.
- Calendar/FY/quarter/month parsing.
- `s`, `f` and `z` status parsing.
- Nominal/real and currency separation.
- Physical unit normalisation.
- Missing-value reasons.
- Current-view precedence and conflict behavior.
- Series catalogue.
- Revision and forecast-error matching.
- Typed errors and warnings.
- Offline/local-file operation.

### 17.4 Golden assertions

At minimum:

- 23 forecast and 47 historical sheets in the June 2026 fixture;
- the December 2025 to June 2026 export-value revision in section 2;
- the June 2026 release ID comes from the landing page despite the historical workbook saying June 2025;
- `s`, `f` and `z` map correctly;
- one calendar-year commodity production series;
- one Australian financial-year export series;
- one quarterly production series;
- one monthly benchmark price series;
- one export-destination series;
- literal `na` becomes numeric `NA` with a non-blank missing reason;
- nominal and real observations have different `series_id` values;
- current-view observation keys are unique or explicitly flagged conflicts.

### 17.5 Live tests

Gate behind `READREQ_LIVE_TESTS=true`.

Live validation must:

- enumerate the current official index;
- preserve the missing March 2026 edition;
- download the latest three assets;
- confirm both workbooks are readable;
- parse at least one overview, quarterly, commodity and historical table;
- cross-check two values manually against the official workbook;
- record hashes and timings;
- avoid the default package and Chartwell test suites.

## 18. Validation reports

For each release and asset, generate:

- actual versus recognised sheets;
- semantic table mapping;
- parser profile selected;
- row counts by table;
- series counts by frequency, status, commodity and concept;
- period ranges;
- unknown units/currencies/statuses;
- unparsed non-empty cells;
- missing-value marker counts;
- duplicate observation keys;
- current-view conflicts;
- internal metadata discrepancies;
- structural breaks;
- source hashes and parser version.

The validation report is a returned object and a saved parsed-cache artifact. It must be readable without rerunning the parse.

## 19. Performance and memory targets

Measure cold and warm behavior on the manager's standard machine.

Initial targets:

- warm release listing: under 100 ms;
- one cached sheet parse: under 1 second;
- complete forecast workbook parse: under 8 seconds;
- complete historical workbook parse: under 30 seconds;
- parsed current-view cache restore: under 1 second;
- peak RSS delta for one complete release: under 300 MB;
- no network access for an exact release already present in raw cache;
- filters may avoid parsing unrelated sheets only when a valid parsed cache or deterministic sheet catalogue exists.

Report at least three runs with min/median/max and peak RSS. Profile XML/Excel reading and row binding before changing targets.

## 20. Licensing, attribution and terms

The June 2026 workbooks state that material is licensed under CC BY 4.0 except the Commonwealth Coat of Arms, trademarks and third-party material.

The package must:

- expose official attribution text through `req_attribution()`;
- retain table-level source notes and third-party labels;
- avoid bundling logos;
- document the data licence separately from the package code licence;
- decide and document whether fixtures redistribute official workbook content or use reduced derived fixtures;
- retain links to the exact release and source asset;
- make clear that public package code does not grant rights to excluded third-party material.

## 21. Documentation deliverables

Required:

- README with latest-release and exact-release examples;
- full exported-function reference;
- “Understanding the two REQ workbooks” vignette;
- “Periods, statuses, units and price bases” vignette;
- “All sheet and table families” vignette;
- “Comparing REQ vintages and forecast errors” vignette;
- cache/offline-use guide;
- source attribution and terms page;
- supported-release matrix;
- `NEWS.md`;
- contribution and code-of-conduct files if public.

Package-check examples must not download live data.

## 22. Implementation phases

### Phase 0 — contract and workbook spike

Deliverables:

- package skeleton;
- dependency decision record;
- release, raw-asset and observation schemas;
- semantic catalogue for all 23 + 47 sheets;
- parser-family map;
- fixture/licensing decision.

Exit criteria:

- manager approves public API and current-view policy;
- December 2024, June 2025 and June 2026 overview sheets are parsed by a prototype without relying on fixed column numbers;
- June 2026 release identity ignores the incorrect internal date.

### Phase 1 — discovery, retrieval and cache

Deliverables:

- official index and release-page parsers;
- exact release listing;
- gap preservation;
- asset-role classification;
- atomic download/cache/hash layer;
- typed transport errors;
- offline HTML fixtures.

Exit criteria:

- all 59 audited releases are enumerated;
- March 2026 is not invented;
- repeated exact-release retrieval is idempotent;
- invalid spreadsheet payloads are rejected.

### Phase 2 — forecast workbook

Deliverables:

- forecast sheet catalogue;
- overview, quarterly and commodity parser families;
- release profiles;
- period/status/unit normalisers;
- forecast reported view and validation.

Exit criteria:

- all 23 sheets map;
- all data-bearing sheets parse;
- all current commodity families are present;
- no unexplained non-empty data cells are dropped.

### Phase 3 — historical workbook

Deliverables:

- historical sheet catalogue;
- annual, quarterly, monthly, commodity and market parsers;
- missing-value handling;
- historical reported view and validation.

Exit criteria:

- all 47 sheets map;
- Tables 1–41 parse;
- annual, quarterly and monthly golden values pass;
- incorrect internal edition metadata produces a warning, not a wrong release ID.

### Phase 4 — current view and catalogue

Deliverables:

- versioned stitching manifest;
- current view;
- semantic series catalogue;
- conflict reporting;
- documentation of precedence.

Exit criteria:

- current-view keys are unique or explicit conflicts;
- nominal/real and CY/FY series remain separate;
- each chosen row retains source-dataset provenance.

### Phase 5 — vintages and forecast errors

Deliverables:

- history-revision comparison;
- forecast-revision comparison;
- first-realisation and latest-revised error calculations;
- status-transition logic;
- vintage vignette.

Exit criteria:

- section 2 revision is reproduced;
- incompatible basis/unit series cannot join;
- first-realisation and latest-revised errors remain distinct.

### Phase 6 — hardening and release candidate

Deliverables:

- validation artifacts for all 59 releases;
- live opt-in test;
- performance/RSS report;
- complete documentation;
- Chartwell compatibility review;
- `v0.1.0` release candidate.

Exit criteria:

- `R CMD check --as-cran` passes without errors or warnings and only justified notes;
- clean-session offline tests pass;
- separate reviewer reproduces tests, golden values and benchmarks;
- every definition-of-done item passes.

## 23. Manager execution and review model

Recommended pull requests:

1. skeleton, contracts and source catalogue;
2. discovery/download/cache;
3. forecast workbook parsers;
4. historical workbook parsers;
5. current view and catalogue;
6. vintage comparisons;
7. documentation, benchmarks and release candidate.

Use a reviewer who did not implement the parsers. The reviewer must inspect raw workbook cells against returned observations and attempt to break status, period, unit and stitching logic.

Each pull request must include:

- exact commands and output;
- fixture coverage;
- public API changes;
- validation summaries;
- known limitations;
- confirmation that no Chartwell app code was modified.

Do not begin app integration until Phase 6 exits.

## 24. Definition of done

`readreq` is complete for `v0.1.0` only when:

- all 59 audited releases are discoverable and supported;
- release gaps are preserved;
- all 23 forecast and 47 historical sheets are classified;
- every data-bearing sheet parses;
- the full commodity list is retained;
- release identity comes from official page metadata;
- raw assets are immutable and hashed;
- periods, statuses, units, currencies and price bases are explicit;
- historical and forecast workbooks remain distinguishable;
- the current view follows a versioned precedence policy;
- history revisions, forecast revisions and forecast errors are separate operations;
- missing and confidential values are not converted to zero;
- offline fixtures cover every parser path;
- live tests are opt-in;
- package checks pass;
- latency and RSS evidence is recorded;
- attribution and third-party exclusions are documented;
- a separate reviewer reproduces the evidence; and
- Chartwell can install a pinned commit, list series and request `release = "latest"` without knowing workbook layout.

## 25. Required handoff evidence

The implementation manager must return:

- repository URL and pinned commit;
- package version;
- exported API listing;
- exact package-check and test commands with pasted output;
- fixture and supported-release matrices;
- sheet/table mapping report;
- parsed row and series counts by release;
- golden-value comparison report;
- current-view conflict report;
- cold/warm timing table with at least three repetitions;
- peak RSS delta;
- final live-validation asset hashes;
- licence/attribution decision;
- unsupported historical releases and reasons;
- unresolved limitations; and
- recommendation on the timing of Chartwell integration and `v0.1.0`.

An implementation summary without this evidence is not an accepted handoff.
