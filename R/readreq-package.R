#' readreq: Reproducible Resources and Energy Quarterly Data
#'
#' `readreq` is a source-specific R client for the Australian Government's
#' Resources and Energy Quarterly (REQ) releases.  It is intended for
#' analysts, researchers, and data stewards who need release-aware
#' observations that can be checked, compared, and replayed offline.  It is
#' not a general-purpose workbook, PDF, or government-data API client.
#'
#' @section Coverage of editions, assets, and observation dates:
#'
#' REQ itself begins with the September 2011 edition. The installed catalogue
#' contains every audited REQ edition from that inaugural release through June
#' 2026: September and December 2011, all four quarterly editions in each year
#' from 2012 through 2025, and June 2026. This is 59 editions in total, not a
#' March-only collection. There is no 2010 or 2000 REQ edition; publications
#' before September 2011 belong to predecessor ABARE/ABARES product families
#' and are outside this package's REQ source contract.
#'
#' Publication coverage does not determine observation coverage. Historical
#' tables within supported editions can contain observations from 2000 or
#' earlier, and period ranges are series-specific. Inspect `period_start`,
#' `period_end`, and source metadata in the returned rows, or use
#' [req_series_catalog()] to explore the series available in an edition.
#'
#' Asset coverage also varies by edition. Fifty-seven editions have at least
#' one structured workbook surface; `req-2011-12` and `req-2013-03` use an
#' audited report-table fallback with a narrower supported surface. Use the
#' `asset_roles` field in [list_req_releases()] rather than assuming that every
#' edition supplies both forecast and historical workbooks.
#'
#' @section Start with a release:
#'
#' Begin with [list_req_releases()] to inspect the bundled release manifest and
#' choose an exact `req-YYYY-MM` identifier.  [read_req()] reads a coherent
#' forecast and/or historical release.  Use [read_req_forecasts()] or
#' [read_req_history()] when one surface, or a surface-specific filter, is
#' clearer.  [download_req_release()] and [validate_req_release()] expose the
#' lower-level download and source-validation steps.
#'
#' @section Discover tables and compare vintages:
#'
#' [req_source_catalog()] describes the supported source tables and parser
#' families, while [req_series_catalog()] inspects the semantic series
#' available in a release.  Once observations from more than one edition are
#' available, [compare_req_vintages()] dispatches to
#' [req_history_revision()], [req_forecast_revision()], or
#' [req_forecast_error()] for the corresponding comparison.  The small
#' helpers [req_status()] and [req_missing_reason()] make status and missing
#' value handling explicit.
#'
#' @section Observation and provenance contract:
#'
#' The readers return ordinary `data.frame` objects with the 35 fields in
#' [req_observation_schema()].  Each row retains release identity, source
#' asset and sheet, table and semantic dimensions, period and status, unit and
#' value fields, missingness and footnote information, stable `series_id` and
#' `observation_key` identifiers, and source provenance (`retrieved_at`,
#' `sha256`, and `parser_version`).  `release_date`, `period_start`, and
#' `period_end` are `Date`; `retrieved_at` is UTC `POSIXct`; `value` is
#' numeric; and `footnote_codes` is a list-column of character vectors.  The
#' specialised readers may add `canonical_selection` and, in reported view,
#' `canonical_conflicts`; [read_req()] in current view may add `conflicts` for
#' unresolved cross-asset keys. Row order follows
#' parser and source order; it is not a promise that rows are sorted by
#' period.
#'
#' `view = "current"` on [read_req()] applies the package's versioned
#' cross-asset precedence policy.  `view = "reported"` preserves source
#' presentations for audit and reconciliation.  The specialised readers use
#' the same observation contract and expose a canonical view by default.
#' Treat [req_observation_schema()] as the source of truth when validating
#' downstream code; release and raw-asset metadata contracts are available
#' from [req_release_manifest_schema()] and
#' [req_raw_asset_manifest_schema()].
#'
#' @section Offline use, network, and cache:
#'
#' [list_req_releases()] and [req_source_catalog()] read small static
#' catalogues bundled with the package.  They do not make a network request or
#' write a cache; `refresh` on the release-list helper is retained for API
#' compatibility and does not turn it into live discovery.  The package also
#' ships reduced, structurally faithful synthetic workbook fixtures for
#' deterministic examples and tests; they contain no official observations.
#'
#' An exact local workbook or local bundle can be passed to the readers for a
#' fully offline workflow. For catalogue release IDs, uncached assets are
#' retrieved from the bundled HTTPS URLs by the default transport. A supplied
#' manifest or `readreq.transport` hook can use another controlled source. No
#' credentials are requested, stored, or sent by the package, and local input
#' paths are not uploaded. Raw assets are
#' retained as immutable, content-addressed snapshots; parsed and reconciled
#' results are keyed by source hashes and parser/policy versions and written
#' atomically.  The default cache location is [req_cache_dir()] (an
#' `R_user_dir()` location); pass `cache_dir` to isolate a workflow.  Caches
#' are not pruned automatically, so a long-lived cache can grow until the user
#' removes entries explicitly.  `refresh = TRUE` rebuilds the requested
#' artefact and leaves older immutable raw snapshots in place.
#'
#' @section Scope, limitations, and failures:
#'
#' The checked-in catalogue is a reviewed snapshot, not a promise that every
#' current or historical government URL remains available.  Early catalogue
#' entries use HTTPS web-archive endpoints, and a release can be missing a
#' structured workbook or have a changed source layout.  Readers admit only
#' the source layouts represented by the package catalogue; changed, malformed,
#' unavailable, or semantically ambiguous assets fail with typed `req_*`
#' conditions rather than being silently coerced.  See individual reference
#' topics for the relevant condition classes and remediation guidance.
#'
#' The report-table fallback for `req-2011-12` and `req-2013-03` requires
#' Poppler's `pdftotext` executable on `PATH`.  It is optional for workbook
#' workflows and is not downloaded or installed by the package.  If it is not
#' available, those report-backed reads fail rather than pretending that a
#' structured workbook exists.
#'
#' @section Source terms and package licence:
#'
#' [req_attribution()] returns attribution guidance, not a legal determination
#' for every release or asset.  Current Resources and Energy Quarterly
#' materials identify CC BY 4.0 subject to source-stated exclusions such as
#' the Commonwealth Coat of Arms, third-party content, logos, trade marks, or
#' other noted material.  Historical editions can carry different terms (for
#' example, CC BY 3.0 Australia), so check the licence and attribution notice
#' attached to the specific edition before redistributing source material.  An
#' official starting point is the [Resources and Energy Quarterly
#' publications page](https://www.industry.gov.au/publications/resources-and-energy-quarterly).
#' **Package code:** MIT, copyright Chartwell Macro.  The same package licence covers
#' the package-authored synthetic example fixtures and documentation assets,
#' except for the official-data-derived iron ore chart used by the README and
#' Getting Started article. That figure adapts March 2024, March 2025 and June
#' 2026 REQ forecast tables plus the June 2026 historical table. Each source
#' publication states CC BY 4.0 subject to named exclusions; the selected
#' tables credit ABS Cat. No. 5368.0, the Department of Industry, Science and
#' Resources, and other named sources. The chart contains no source logo, Coat
#' of Arms, or decorative publication content. See the installed `COPYRIGHTS`
#' file for its provenance and rights boundary. Official publications,
#' runtime-downloaded source data, upstream material, logos and other
#' third-party content remain
#' subject to their own edition-level or upstream terms.
#'
#' @section Author and maintainer:
#'
#' The package author, maintainer and copyright holder is **Chartwell Macro**.
#'
#' @author Chartwell Macro
#'
#' @seealso
#'   [list_req_releases()], [read_req()], [read_req_forecasts()],
#'   [read_req_history()], [download_req_release()],
#'   [validate_req_release()], [req_source_catalog()],
#'   [req_series_catalog()], [compare_req_vintages()],
#'   [req_observation_schema()], [req_cache_dir()], [req_attribution()]
#'
#' @docType package
#' @name readreq-package
#' @aliases readreq
#' @import data.table
#' @keywords internal
"_PACKAGE"
