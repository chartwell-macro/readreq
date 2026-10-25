# readreq 0.1.0

- Provides the complete 59-edition Resources and Energy Quarterly catalogue
  from September 2011 through June 2026.
- Reads and validates all structured forecast and historical workbook tables
  in 57 editions.
- Reads audited Key macroeconomic assumptions from the December 2011 and March
  2013 reports.
- Adds release-specific workbook profiles for legacy XLS/XLSX structures,
  split grids, control rows, monthly histories and revised table families.
- Records source hashes, parser provenance, output hashes and validation
  results for every supported edition.
- Supports immutable caching, offline replay, reported/canonical/current views,
  series catalogues and vintage comparisons.
