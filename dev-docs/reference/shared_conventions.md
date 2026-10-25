# Shared conventions for `readreq` and `readagau`

Status: frozen Stage 0 contract  
Frozen: 2026-07-27  
Applies to: `readreq` and `readagau`

This contract reconciles `readreq` implementation plan §7.3 and `readagau`
implementation plan §8.3. The package plans remain authoritative. This
document records their compatible shared core and package-specific extensions;
it does not replace either plan.

## 1. Observation contract

Both packages expose the following shared core, with the same names and
meanings:

| Field | Type | Meaning |
|---|---|---|
| `product` | character | Stable source product; `resources_energy_quarterly` for `readreq` |
| `release_id` | character | Exact release or snapshot vintage |
| `release_date` | Date | Official landing-page publication date |
| `dataset` | character | Stable logical dataset |
| `source_dataset` | character | Physical source dataset/workbook; retained even in canonical views |
| `source_asset` | character | Product-specific asset role |
| `source_sheet` | character | Actual workbook sheet label, or structured-source label |
| `table_id` | character | Stable semantic table identifier |
| `table_title` | character | Published title |
| `record_role` | character | `canonical` or `supporting` |
| `geography_type` | character | Published geography level, or `not_applicable` |
| `geography` | character | Normalised published geography |
| `commodity` | character | Normalised commodity, product or aggregate |
| `concept` | character | Normalised published measure |
| `period` | character | Published target period without a status suffix |
| `period_start` | Date | Parsed lower bound where defensible |
| `period_end` | Date | Parsed upper bound where defensible |
| `period_basis` | character | Calendar, financial, marketing/crop year, quarter, month, week or explicit other basis |
| `period_status` | character | `historical`, `estimate`, `forecast`, `projection` or `published-unclassified` |
| `status_source` | character | `suffix`, `header`, `title`, `note`, `landing-page` or `unclassified` |
| `price_basis` | character | Nominal, real, unit value, spot, contract, benchmark, index basis or `not_applicable` |
| `currency` | character | Published currency, or `not_applicable` |
| `unit` | character | Normalised published unit |
| `value` | double | Parsed value; never zero-filled |
| `raw_value` | character | Original cell representation |
| `missing_reason` | character | Controlled missing reason, or `NA` for a present value |
| `footnote_codes` | list<character> | Published codes attached to the observation |
| `source_note` | character | Relevant source/definition note |
| `series_id` | character | Deterministic key over all semantic dimensions except target period and vintage |
| `observation_key` | character | `series_id` plus target period |
| `retrieved_at` | POSIXct UTC | Asset retrieval time |
| `sha256` | character | Lower-case 64-character source asset hash |
| `parser_version` | character | Parser/profile version |

`readreq` extensions are `section` and `frequency`.

`readagau` extensions are `report_number`, `sector`, `season`, `market`,
`method`, `source_provider`, `rights_status`, `observation_date`,
`snapshot_date` and `source_cadence`. Fields that do not apply to a source are
present with an explicit `not_applicable` value where the field is categorical,
or typed `NA` where it is a date or identifier.

Both `dataset` and `source_dataset` are retained. `dataset` is the stable
logical dataset used by both packages. `source_dataset` identifies the physical
workbook/feed chosen for an observation and is therefore indispensable to
canonical-view provenance.

Semantic keys never combine observations with different product, dataset,
geography, commodity, concept, period basis, price basis, currency, unit,
market or method. For `readreq`, `period_status` is always part of
`series_id`, exactly as required by its plan §7.3. `readagau` retains every
source semantic dimension required by its plan.

## 2. Status and transitions

Precedence is:

1. explicit period suffix;
2. explicit row/column header;
3. explicit table/sheet title;
4. explicit workbook note or legend;
5. explicit landing-page description where the source supports it;
6. otherwise `published-unclassified`.

Suffixes are `s` → `estimate`, `f` → `forecast`, and `z` → `projection`.
Neither package infers history/finality solely from a target period preceding
the release date.

Recognised transitions are:

- `forecast → forecast`;
- `forecast → estimate`;
- `forecast → projection`;
- `projection → projection`;
- `projection → forecast`;
- `estimate → estimate`;
- `estimate → historical`; and
- `historical → historical` (a history revision when the value changes).

## 3. Missing values

`value` is `NA_real_` for source missing markers while `raw_value`,
`missing_reason`, footnotes and confidentiality/source notes are retained.
Controlled reasons are:

- `blank`;
- `provider_na`;
- `not_applicable`;
- `unavailable`;
- `confidential`;
- `suppressed`; and
- `parse_failure`.

Missing, confidential, suppressed or non-numeric values are never converted to
zero. A known source missing marker is data. An unexplained non-empty value in a
numeric region is a typed parse/validation error; `parse_failure` may appear in
a diagnostic record but is not silently returned as an ordinary observation.

## 4. Manifests

The release-manifest core is:

`product`, `release_id`, `release_date`, `edition`, `landing_url`,
`asset_roles`, `asset_status`, `support_status`, `unsupported_reason`,
`discovered_at`, `discovery_version`, `warning`.

`readreq` additionally carries `forecast_url`, `historical_url` and
`report_url`. `readagau` additionally carries `report_number`.

The raw-asset-manifest core is:

`product`, `release_id`, `asset_type`, `source_url`, `source_filename`,
`detected_format`, `content_type`, `retrieved_at`, `etag`, `last_modified`,
`sha256`, `bytes`, `local_path`, `validation_status`, `unsupported_reason`.

Release identity comes from official landing-page metadata, never the filename
or an internal workbook title. Release manifests record actual discoveries and
never manufacture cadence gaps.

## 5. Immutable cache

Raw paths are content-addressed:

```text
raw/<product>/<release_id>/<sha256>/<asset>
```

`readreq` may omit the constant product segment in its on-disk convenience
layout, but its manifest still carries `product`. Exact raw snapshots are
immutable. Writes use a temporary file followed by an atomic promotion after
signature, size and SHA-256 validation. Existing bytes under a hash path are
never replaced. Refreshing discovery never deletes raw assets. Parsed cache
keys include product, release, all source hashes, parser version, output view
and rights-manifest version where applicable. Pruning is explicit and scoped;
it is never automatic.

## 6. Vintage operations

The operations are separate in both packages and share these signatures after
the package namespace prefix:

```r
*_history_revision(data, releases = NULL, series = NULL)
*_forecast_revision(data, releases = NULL, series = NULL)
*_forecast_error(
  data,
  releases = NULL,
  series = NULL,
  realisation = c("first", "latest_revised")
)
```

The prefixes are `req_` and `agau_`. History revision requires comparable
non-forecast observations. Forecast revision requires the earlier observation
to be a forecast or projection. Forecast error defaults to the first later
estimate/historical observation; `latest_revised` is explicitly named and is
never labelled as the original forecast error. Within each vintage,
`observation_key` must be unique. Cross-vintage operations require compatible
unit, currency, price basis, period basis, geography and structural-break
state.

Because `readreq` status is part of public `series_id`, revision engines use an
internal status-independent comparison join key over all otherwise identical
semantic dimensions plus target period. That internal key is never exposed as
or substituted for `series_id`. The join must be unique and results retain both
old/new `series_id` and old/new status so transitions remain explicit.

## 7. Conditions

Every condition carries, when relevant, `product`, `release_id`, `asset_type`,
`source_sheet`, `table_id`, `series_id` and a concise `remediation` hint.

Common semantic families are discovery, asset missing, download, asset format,
schema, table/sheet parse, period parse, unit conflict, canonical/stitch
conflict, endpoint, rights and validation. Concrete class names retain the
package prefixes required by each authoritative plan:

- `readreq`: `req_release_discovery_error`, `req_release_gap_warning`,
  `req_asset_missing_error`, `req_download_error`,
  `req_asset_format_error`, `req_workbook_schema_error`,
  `req_sheet_parse_error`, `req_period_parse_error`,
  `req_unit_conflict_error`, `req_stitch_conflict_error`,
  `req_validation_error`.
- `readagau`: `agau_release_discovery_error`,
  `agau_asset_missing_error`, `agau_download_error`,
  `agau_asset_format_error`, `agau_schema_error`,
  `agau_table_parse_error`, `agau_endpoint_error`, `agau_rights_error`,
  `agau_status_warning`, `agau_duplicate_warning`,
  `agau_cadence_warning`, `agau_validation_error`.

Unknown structural fingerprints, unexplained non-empty numeric cells,
ambiguous canonical collisions, non-unique vintage joins and incompatible
semantic bases fail loudly. Documented release gaps, internal metadata
discrepancies and safely preserved source anomalies warn without dropping
provenance.

## 8. Fixture and gated-source decision

Committed fixtures are **REDUCED/DERIVED synthetic, structurally faithful
fixtures only**. They may reproduce shapes, headers, merges, notes and failure
modes, but never full official workbooks, official logos, the Commonwealth Coat
of Arms, decorative report content or third-party values. Full official assets
remain outside package repositories; opt-in regression manifests may record
their hashes without redistributing them.

Weekly commodity prices and fertiliser are **not admitted** unless both a
documented stable official structured endpoint and reviewed reuse rights exist.
Until both gates pass, catalogues expose metadata only with
`unsupported_reason`; public value paths return no values. Chart pixels,
unversioned private endpoints and inferred permission cannot satisfy the gate.
