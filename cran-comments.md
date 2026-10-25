# CRAN comments

## Release status

This branch prepares `readreq` 0.1.0 as an initial CRAN release candidate. No
CRAN submission has been made and CRAN acceptance is not claimed.

The package author, maintainer and copyright-holder name is **Chartwell Macro** in
`Authors@R`, `LICENSE`, citation and copyright metadata.

Package code and package-authored synthetic assets are MIT-licensed, copyright
Chartwell Macro. Official publications, runtime-downloaded source data, upstream code,
logos and third-party material are not reassigned or relicensed by the package;
their edition-specific or upstream terms remain in force.

The README and Getting Started article include one rendered chart derived from
the June 2026 quarterly iron ore export-volume history and forecast paths from
the March 2024, March 2025 and June 2026 REQ editions. The source workbooks and
extracted rows are not bundled. The figure is explicitly outside the package
MIT licence, attributes DISR and ABS, retains the source-stated third-party
rights boundary, contains no source logo or Coat of Arms, and has the source
terms and exclusions recorded in `inst/COPYRIGHTS`.

Before submission, the maintainer must make the repository, issue tracker and
pkgdown site publicly reachable and confirm that the configured non-personal
maintainer address can receive CRAN correspondence. These are external release
blockers; this branch does not change repository visibility or invent another
address.

## Test environment

- Local: macOS Sequoia 15.6, Apple silicon
  (`aarch64-apple-darwin24.4.0`), R 4.5.1 (2025-06-13), UTF-8.
- The most recent completed GitHub Actions run before this chart-simplification
  amendment,
  [32731434575](https://github.com/chartwell-macro/readreq/actions/runs/32731434575)
  completed successfully for the documentation-and-chart commit
  `pre-publication baseline` on 2026-08-24. Every matrix
  job reported `Status: OK`:
  - Ubuntu 24.04.4, R-devel 4.7.0;
  - Ubuntu 24.04.4, R release 4.6.1;
  - Ubuntu 24.04.4, R oldrel-1 4.5.3;
  - macOS Tahoe 26.5.2 on Apple silicon, R release 4.6.1; and
  - Windows Server 2022 UCRT, R release 4.6.1.

No Win-builder or R-hub result is claimed in this file.

## R CMD check results

The source tarball was built with `R CMD build .` and checked from a disposable
directory with:

```sh
R CMD check --as-cran readreq_0.1.0.tar.gz
```

- Tarball: `readreq_0.1.0.tar.gz`, 377 KB (385,772 bytes).
- SHA-256: `465807762f9ca00dd21c0d7dc3154111ba8629950e4e471e51cccbf327b14075`.
- Check directory:
  `/private/tmp/readreq-iron-chart-exact-check.wWVZJX/readreq.Rcheck`.
- Result: 0 errors, 0 warnings, 1 note.

The note is the new-submission URL check. The GitHub repository, issue
tracker, repository-file links and GitHub Pages site returned HTTP 404 to an
unauthenticated client. It was not suppressed or reclassified.

All package examples, tests, five vignettes, vignette rebuilding, PDF/HTML
manuals, dependency checks and install/load checks passed. No example timing
note remained in the final uncontended check.

## Additional verification

- Documentation-amendment commit
  `pre-publication baseline` completed the five-platform
  [R CMD check matrix](https://github.com/chartwell-macro/readreq/actions/runs/32731434575),
  [pkgdown configuration/site build](https://github.com/chartwell-macro/readreq/actions/runs/32731434564),
  and [test-coverage run](https://github.com/chartwell-macro/readreq/actions/runs/32731434592).
  The Pages deployment job was correctly skipped because the amendment branch
  was not the repository default branch.
- A clean isolated installation of the final tarball succeeded and occupied
  956 KB. Installed metadata retained the 59-edition coverage statement,
  `COPYRIGHTS` record and documentation figure.
- The installed metadata reports `Author: Chartwell Macro [aut, cre, cph]` and the
  maintainer name as `Chartwell Macro`; `DESCRIPTION` supplies the required non-personal
  maintainer address. The installed citation, package topic and licence use
  `Chartwell Macro`. Case-insensitive fixed-string scans found zero occurrences of the
  forbidden personal Gmail address in tracked files, the built tarball, the
  isolated installation and the generated website. A broader inventory found
  only the required non-personal maintainer address in `DESCRIPTION` and
  generated package metadata; optional/public sources, Rd, vignettes,
  citations and site output contained no email-like strings. Root
  `CITATION.cff` is excluded from the tarball, while `inst/CITATION` is
  installed.
- The full offline source suite reported 360 successful expectations, one
  intentional skip for maintainer-only source-file validation, and no failures,
  errors or warnings.
- `README.Rmd` was rendered to the tracked `README.md`; all five vignettes were
  rendered directly and rebuilt by `R CMD check`.
- `pkgdown::check_pkgdown()` passed. A disposable pkgdown build produced 106
  files (3.7 MB), including five articles and all public reference topics; an
  internal scan checked 990 relative links/assets across 36 HTML pages and
  found zero broken targets.
  Home, grouped reference and article output were inspected. The responsive
  `width="100%"` figure markup was retained. Desktop-site and 420-pixel chart
  inspection found the coverage hierarchy, four-line chart, legend and
  attribution readable without clipping. Pandoc emitted only its own
  `--highlight-style` deprecation message.
- The README homepage and Getting Started article show an end-to-end
  `list_req_releases()` -> `req_source_catalog()` -> `read_req_history()` plus
  `read_req_forecasts()` -> `ggplot2` workflow. It charts 145 historical
  quarterly iron ore export-volume observations from 1990-Q1 through 2026-Q1
  with 22, 24 and 22 forecast/projection observations from the March 2024,
  March 2025 and June 2026 editions. The historical `kt` values are converted
  to the forecast table's `Mt` unit. The visible plotting code uses
  `period_start`, `value`, `series`, `geom_line()`, concise labels and
  `theme_minimal(base_size = 13)`. Live retrieval is not executed during
  package builds; the checked-in 1036 by 604 PNG is regenerated by a
  maintainer-only script that verifies all four source workbook hashes. The
  PNG has SHA-256
  `ef3f97f8e451edce60dc04c96d93c60674d5689b9ff0ab9847364189d9b291e9`.
- Coverage prose now distinguishes three independent dimensions: all 59 actual
  REQ editions from the series' September 2011 inception through June 2026;
  edition-specific asset roles (57 structured and two report-only fallbacks);
  and series-specific observation periods that can reach 2000 or earlier.
  Pre-2011 ABARE/ABARES products are documented as predecessor families, not
  missing REQ editions.
- `urlchecker::url_check()` found only the inaccessible GitHub repository,
  issue, repository-file and GitHub Pages targets described above. A system
  spell-checker was unavailable, so no spelling-check result is claimed.
- All 21 `R/*.R` files retain executable parse trees identical to default-branch
  base commit `pre-publication baseline`; this amendment changes only
  roxygen comments in `R/readreq-package.R` and `R/release-discovery.R`. The 19
  exports, closure types, signatures and defaults are unchanged. The
  package-topic source evaluates only the standard `"_PACKAGE"` marker.
- A normalized functional snapshot covering catalogues, schemas, readers,
  classes, attributes, values, dates, warnings/errors and cache side effects
  is byte-identical before and after. Both snapshots have SHA-256
  `25e3e8efc0077630f08f0ef4ba5a7f92bbec702f6523a3c30369f77cd41ca482`.
- Matched offline performance used two persistent R workers with opposite
  baseline/final order, unchanged fixtures, warmups and zero transport calls.
  Forecast parsing (40 repetitions per arm) changed from median 2.1970 s / p95
  3.27065 s to 2.1955 s / 3.39345 s (-0.07% / +3.75%). Historical parsing
  (20 repetitions per arm) changed from 5.7820 s / 6.87785 s to 5.6245 s /
  6.78715 s (-2.72% / -1.32%). Batched warm-cache reads (100 repetitions per
  arm, 200 reads per timing batch) had two execution-order strata; both met the
  budgets: median changes +3.00% and -0.78%, and p95 changes +0.92% and -0.48%.
  Output digests and network-call counts matched in every comparison.
- Four read-only Chartwell provider/registry/conformance/search contract test
  files passed against the isolated final installation. An earlier run shared
  the host with check and benchmark workloads and missed one 0.5-second
  downstream timeout by 13 ms; the uncontended rerun passed.

Reverse-dependency checks were not run because this is an initial release and
`readreq` was absent from the checked current and archived CRAN and
Bioconductor package indexes on 2026-08-24.
