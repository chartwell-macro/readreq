# readreq 0.1.0

- Updates package documentation, source-rights guidance and release metadata
  for a CRAN-ready release candidate; no CRAN submission or acceptance is
  implied.
- Standardises the package author, maintainer and copyright-holder name as
  `Chartwell Macro` across public, citation and legal package metadata.
- Makes the rights boundary explicit throughout the installed documentation:
  package code and package-authored synthetic assets are MIT-licensed,
  copyright Chartwell Macro, while official publications, downloaded source data and
  third-party material retain their own terms.
- Adds a real end-to-end `read_req_history()` plus `read_req_forecasts()`
  workflow and one rendered chart of Australian quarterly iron ore export
  volumes: the full 1990-Q1 to 2026-Q1 history and forecast paths from the
  March 2024, March 2025 and June 2026 REQ editions. Documentation builds use
  the checked-in derived figure and do not bundle or download source workbooks.
- Distinguishes the 59-edition publication catalogue (September 2011 to June
  2026) from edition-specific asset roles and series-specific observation
  periods, which can extend to 2000 or earlier. Pre-2011 ABARE/ABARES products
  are documented as predecessor product families rather than missing REQ
  editions.
- Adds repository hygiene for reproducible package checks while preserving the
  package's documented source and output contracts.
- Provides the complete audited 59-edition Resources and Energy Quarterly catalogue
  from September 2011 through June 2026.
- Reads and validates edition-specific structured workbook surfaces—forecast,
  historical, statistical or commodity as applicable—across 57 workbook-backed
  editions.
- Reads audited Key macroeconomic assumptions from the December 2011 and March
  2013 reports.
- Adds release-specific workbook profiles for legacy XLS/XLSX structures,
  split grids, control rows, monthly histories and revised table families.
- Records source hashes, parser provenance, output hashes and validation
  results for every supported edition.
- Supports immutable caching, offline replay, reported/canonical/current views,
  series catalogues and vintage comparisons.
- Documents GitHub installation and keeps engineering records under
  the package-owned `dev-docs/` directory.
