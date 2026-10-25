# Documentation source map

This map keeps the public documentation tied to package behavior. The package
root `README.Rmd` is the authored home-page source; `README.md` is its generated
form. Roxygen comments in `R/` are the source for `man/` and `NAMESPACE`, and
the five files under `vignettes/` are the installed task-oriented articles.
`_pkgdown.yml` groups those same topics for the website. Engineering records
under `dev-docs/` are supporting evidence and must not override those sources.

## Users and jobs

| User need | Canonical public entry point | Behavioral source |
|---|---|---|
| Find an exact edition and its available assets | README source map; `list_req_releases()` help | `R/release-discovery.R`; `inst/catalogue/release-catalog.csv` |
| Retrieve and replay exact source bytes | Cache article; `download_req_release()` help | `R/download.R`; `R/cache.R`; `R/transport.R` |
| Read forecast, historical, or combined observations | Getting-started and reading-workbooks articles; reader help | `R/read-api.R`; parsers; `inst/config/` |
| Validate output and provenance | Reader and schema help; `validate_req_release()` help | `R/contracts.R`; `R/validation.R`; `inst/schema/` |
| Interpret periods, statuses, missing values, and units | Periods/statuses/missingness article | `R/normalise-period.R`; `R/normalise-contracts.R` |
| Compare revisions and forecast errors | Comparing-vintages article; vintage help | `R/vintages.R` |
| Work offline and manage storage | Cache article; `req_cache_dir()` help | `R/cache.R`; parsed-cache helpers in `R/read-api.R` |
| Attribute source material and cite the software | README licensing section; `req_attribution()`; `citation("readreq")` | `R/attribution.R`; `inst/CITATION`; edition source notices |

## Public scope and contracts

- REQ itself begins with September 2011. The static installed catalogue
  contains all 59 audited editions from then through June 2026: September and
  December 2011, all four quarters in 2012--2025, and June 2026. Earlier
  ABARE/ABARES products are predecessor families rather than missing REQ
  editions. Asset roles vary by edition; 57 editions have at least one
  structured workbook surface and two use an audited report-table fallback.
  Historical observation periods are series-specific and can reach 2000 or
  earlier. The catalogue and each row's `asset_roles` are authoritative.
- The 19 exports are those generated into `NAMESPACE`. There are no exported
  package datasets or exported S3 methods.
- Observation readers return the 35 ordered fields described by
  `req_observation_schema()`. Generated help documents field types, relevant
  attributes, view semantics, conditions, network/cache behavior, and side
  effects.
- `list_req_releases()` and `req_source_catalog()` are static and offline.
  String release IDs resolve through the bundled catalogue. A one-row manifest
  supplied to `download_req_release()` is used as supplied, and readers also
  support controlled local inputs and the package transport hook.
- The package does not request, store, or send credentials. Catalogue assets
  use bundled HTTPS URLs, including archived government endpoints for older
  editions. Optional custom transports are caller-controlled.
- Raw and parsed caches are persistent and are not pruned automatically.
  Documentation must state their scope and growth. The report fallbacks for
  `req-2011-12` and `req-2013-03` additionally require Poppler's `pdftotext`.
- Executed public examples and vignettes use reduced synthetic fixtures or
  synthetic observations. The README and Getting Started article additionally
  show opt-in exact-release calls and a checked-in chart of the June 2026 iron
  ore export-volume history with March 2024, March 2025 and June 2026 forecast
  paths; documentation rendering never downloads the workbooks. The figure's
  source terms and exclusions are
  recorded in `inst/COPYRIGHTS`.

## Synchronisation checks

Before release, regenerate `man/`, `NAMESPACE`, and `README.md`; render all
vignettes; build the pkgdown site in a disposable directory; compare exports
against the reference index; and search active documentation for stale
coverage counts, invented edition IDs, or claims that view names are
`record_role` values. The built tarball, not the source directory, is the CRAN
check target.
