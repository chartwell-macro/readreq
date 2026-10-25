# Supported releases

## Edition coverage

Resources and Energy Quarterly (REQ) begins with the September 2011 edition.
`readreq` catalogues every audited REQ edition from that inaugural publication
through June 2026: September and December 2011, all March, June, September and
December editions in 2012--2025, and June 2026. That is 59 editions: 14 March,
15 June, 15 September and 15 December editions. It is not a March-only
collection.

There is no 2010 or 2000 REQ edition. Pre-September-2011 ABARE/ABARES
publications are predecessor product families with distinct sources,
terminology and rights. They are outside the present package contract rather
than gaps in the REQ catalogue.

## Asset coverage

The checked-in catalogue contains 59 audited editions. Asset coverage is
edition-specific: 57 editions expose at least one structured workbook surface,
while December 2011 and March 2013 expose audited Key macroeconomic assumptions
from their official reports. Every edition carries exact source URLs, asset
roles and release metadata; callers should inspect `asset_roles` rather than
assuming that every edition has both forecast and historical workbooks.

The exact asset-role combinations are 36 forecast/historical/report editions,
14 forecast/report editions, one forecast-only edition, one
forecast/historical edition, four early report/statistical/commodity editions,
one early edition with those assets plus historical companions, and two
report-only editions. `list_req_releases()` is the source of truth for each
edition's `asset_roles` and URLs.

## Observation coverage

Edition dates do not bound the periods inside historical tables. Some series
in supported workbooks reach calendar 2000, financial year 2000--01 or
earlier, while other series start much later. The period range is specific to
the table and semantic series. Inspect `period_start`, `period_end`, `unit`,
`source_note` and the other source fields in returned observations, and use
`req_series_catalog()` when exploring an edition.

## Extending coverage

A newly published REQ edition can usually be added efficiently when its source
layout matches an audited parser profile, but it still needs exact catalogue
metadata, source hashes, a release audit and regression tests. A novel layout
requires parser/profile work. Pre-2011 ABARE/ABARES products require a separate
legacy source contract, including source discovery, rights review, taxonomy,
fixtures or golden values and dedicated tests; they should not be inserted as
if they were REQ editions.

The serialized provider certification is
`dev-docs/evidence/release-output-audit-final.csv`. It records asset hashes,
observation, series and table counts, output hashes and validation results for
all 59 editions. Every row is valid with zero unresolved duplicate keys and
zero current-view conflicts.

The evidence file SHA-256 is recorded in
`dev-docs/evidence/release-output-audit-final.csv.sha256`.
