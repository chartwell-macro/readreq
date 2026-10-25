# Data contract

The checked-in machine-readable schemas under `inst/schema/` are
authoritative. This guide explains their public stability.

## Observation identity

`series_id` is derived from semantic dimensions other than target period and
vintage. `observation_key` adds the target period. Neither identifier includes
retrieval time or source hash.

Stable provenance fields include `product`, `release_id`, `release_date`,
`dataset`, `source_dataset`, `source_asset`, `source_sheet`, `table_id`,
`retrieved_at`, `sha256` and `parser_version`.

## Time and status

`period` preserves the normalised source label. `period_start`, `period_end`
and `period_basis` make calendar, financial, quarterly and monthly semantics
explicit. `period_status` uses the controlled vocabulary returned by
`req_status()`, while `status_source` records the evidence used.

## Values and missingness

`value` is numeric. `raw_value` preserves the source token. A source marker
such as `na`, confidential or suppressed becomes numeric `NA` plus a
controlled `missing_reason`; it never becomes zero.

`unit`, `currency` and `price_basis` are separate semantic dimensions.
Footnote markers are retained in `footnote_codes` rather than appended to the
unit.

## Reported and derived roles

`record_role` distinguishes:

- `reported`: admitted source presentation;
- `canonical`: policy-selected value within a workbook surface; and
- `current`: policy-selected value across forecast and historical assets.

Canonical and current selection never removes source provenance. Ambiguous
equal-priority values raise typed conditions.

## Compatibility

Existing field meaning and type are stable within a major version. Adding a
field is normally backwards compatible. Removing, renaming or changing the
meaning of a field requires a versioned migration and release note.
