# Independent Phase 6 review

> Archived milestone review. This document records the earlier nine-release
> candidate and is superseded by `../reference/SUPPORTED_RELEASES.md` and
> `../evidence/release-output-audit-final.csv`.

Date: 2026-07-27  
Package: `readreq` `0.0.0.9000`  
Parser contract: `1.2.0`  
Frozen reviewed content hash: `fe00aaaa8bc6b26c3a47e14c2fc43cf77a12df4a7ed1de29c501cbf26d998d48`

## Verdict

**NOT READY for a `v0.1.0` tag or Chartwell integration.**

The functional implementation passes the independent parser, official-data,
cache, semantic, adversarial, build and ordinary package-check gates. The
remaining release blockers are explicit rather than hidden:

1. **P1 — peak RSS exceeds the mandatory target.** The independent three-run
   June 2026 historical parse measured 418.266 / 482.188 / 528.859 MiB
   min/median/max peak RSS delta. The plan requires less than 300 MiB.
2. **P1 — no installable pinned source identity exists.** The local Git
   repository has no commit and no remote; every source file is untracked.
   Chartwell therefore cannot install the required pinned commit. This review
   intentionally left commit creation to the coordinator's final handoff.
3. **P1 — release metadata is intentionally unfinished.** `DESCRIPTION`
   remains version `0.0.0.9000` and uses
   `chartwellmacro@gmail.com`. The package and its evidence correctly state
   that this is not yet a `v0.1.0` release candidate.
4. **P2 — the formal CRAN-style exit gate is not clean on this host.**
   `R CMD check --as-cran` has no code or test failure but ends with one
   warning and three notes. The warning is the host's missing optional `qpdf`;
   the notes cover development maintainer/version metadata, inability to
   verify the host clock, and old HTML Tidy. The committed evidence reports
   two notes, whereas this independent run produced three.

The package is otherwise functionally ready for release hardening. Resolve or
formally accept the RSS target miss, replace maintainer/version metadata,
create and publish a reviewed commit, and repeat the CRAN-style check before
integration.

## Frozen-state controls

The coordinator declared the source frozen before the final run. The content
hash above was computed before and after the final tests and remained
identical. The hash covers all files under `R/`, `tests/`, `dev-docs/scripts/`, `inst/`
and `docs/`, sorted by path and content hash.

The independent replay was split into three batches only to stay below the
shell process time ceiling. Every batch loaded the same frozen package and
used the same validation script and poisoned network transport.

## Historical nine-release replay

Every release was restored from the exact raw content-addressed cache with
network and discovery transport poisoned. Raw hashes and byte sizes matched
`supported-release-validation.csv`; sheet mappings matched all 630 reference
rows; per-table counts matched all 585 reference rows.

| Release | Forecast rows / series | Historical rows / series | Result |
|---|---:|---:|---|
| `req-2026-06` | 3,013 / 1,066 | 105,228 / 1,385 | pass |
| `req-2025-12` | 2,362 / 1,250 | 103,796 / 1,384 | pass |
| `req-2025-09` | 2,361 / 988 | 103,179 / 1,384 | pass |
| `req-2025-06` | 2,343 / 1,125 | 102,259 / 1,385 | pass |
| `req-2025-03` | 3,076 / 1,116 | 102,651 / 1,879 | pass |
| `req-2024-12` | 2,305 / 1,268 | 102,538 / 1,877 | pass |
| `req-2024-09` | 2,301 / 997 | 101,245 / 1,557 | pass |
| `req-2024-06` | 2,376 / 1,122 | 101,057 / 1,877 | pass |
| `req-2024-03` | 2,876 / 882 | 100,303 / 1,873 | pass |

For every release:

- 23 forecast and 47 historical worksheets classified;
- stored summary, mapping and table-count artifacts matched;
- validation status was `valid`;
- payload delta was zero;
- unknown units, currencies and statuses were zero;
- structural breaks were zero;
- canonical forecast and historical duplicate keys were zero;
- unresolved reported duplicates were zero; and
- current-view conflicts were zero.

June 2026 retained 101,044 rows with nonblank source notes, 1,806 rows with
footnote codes and 5,179 rows with controlled missing reasons. Equivalent
retention counts were positive for all other releases.

## Discovery, gaps and cache

At this historical milestone, nine releases from `req-2024-03` through
`req-2026-06` were audited. The current package certification covers all 59
actual editions from September 2011 through June 2026.

With transport poisoned:

- a complete June 2026 forecast/historical/report request restored all three
  assets and independently verified their SHA-256 hashes;
- a report-only cache satisfied a report-only request; and
- requesting forecast plus report from that partial cache raised the typed
  `req_download_error` instead of returning an incomplete release.

The June 2026 raw hashes reproduced were:

```text
forecast   011d09f15d401830845bf9abf13b3bd2e0baf4bc95ea647bdd03246fe83b01fa
historical d78ba67562f90fd42a137910ed4839aa259a29290ea609b406abe94455ccfc77
report     766d7068ee61a7764c788428c3bfaea4b458ab783e9fc77d78d64e0f5d85691f
```

## Raw-cell and semantic reproduction

The official workbook cells were inspected separately from returned
observations.

| Source | Raw cell value | Returned value |
|---|---:|---:|
| Dec 2025 Commodity sector, 2025–26 export value | 382959.86639541801 | 382959.866395418 |
| Jun 2026 Commodity sector, 2025–26 export value | 404920.36845652701 | 404920.368456527 |
| Jun 2026 quarterly forecast price | 316.67421875000002 | 316.67421875000002 |
| Jun 2026 historical quarterly value | 9890.0059999999994 | 9890.0059999999994 |
| Jun 2026 historical monthly value | 1528.9 | 1528.9 |
| Jun 2026 historical annual value | 145 | 145 |

The exact Dec-to-June comparison returned one revision:

```text
status transition: forecast -> estimate
absolute change:   21960.502061109
old issue date:    2025-12-19
new issue date:    2026-07-03
```

The June observation carries `status_source = "landing-page"`; the December
observation carries `status_source = "suffix"`. The corresponding forecast
error operation remains separate and correctly requires a later
estimate/historical realisation.

Two raw monthly `na` cells returned numeric `NA` with
`missing_reason = "provider_na"`, never zero. Seven June lithium rows use the
clean semantic unit `kt LCE`, while footnote `a` remains separately retained.
Observed currencies were `AUD`, `USD` and `not_applicable`; observed price
bases were contract, index, nominal, real, spot, unit value and not
applicable.

Reported/canonical/current counts for June 2026 were:

```text
forecast reported/canonical:   3,013 / 3,013
historical reported/canonical: 105,228 / 105,228
combined reported/current:     108,241 / 108,238
current conflicts:             0
canonical duplicate keys:      0
```

## Adversarial and automated tests

The frozen full suite, including opt-in official regressions, passed with no
failure, warning or skip:

```sh
READREQ_LIVE_TESTS=true \
READREQ_JUNE_2026_FORECAST=/private/tmp/readreq_june2026_forecast.xlsx \
READREQ_JUNE_2026_HISTORICAL=/private/tmp/readreq_june2026_historical.xlsx \
READREQ_DEC_2025_FORECAST=/private/tmp/readreq_dec2025_forecast.xlsx \
Rscript -e 'testthat::test_local(".", reporter="summary")'
```

The suite covered contracts, current/vintage behavior, official goldens, all
parser families and transport/cache behavior.

Independent workbook mutations reproduced these typed failures:

| Mutation | Result |
|---|---|
| unknown control sheet | `req_workbook_schema_error` |
| moved/unrecognizable period headers | `req_workbook_schema_error` |
| unlabelled value in a period grid | `req_sheet_parse_error` |
| numeric payload outside every recognized block | `req_sheet_parse_error` |
| literal `na` outside every recognized block | `req_sheet_parse_error` |

The unmodified synthetic forecast workbook still parsed 168 observations.
Forecast-to-forecast and forecast-to-estimate revisions, first-realisation and
latest-revised errors, history revisions, status-independent stitching and
ambiguous-conflict behavior all passed their dedicated tests.

## Independent performance reproduction

The benchmark was run from a frozen temporary package copy so its CSV output
could not modify the reviewed repository:

```sh
Rscript dev-docs/scripts/benchmark-release.R \
  /private/tmp/readreq_june2026_forecast.xlsx \
  /private/tmp/readreq_june2026_historical.xlsx \
  /private/tmp/readreq-supported-cache
```

| Benchmark | Min | Median | Max | Target | Result |
|---|---:|---:|---:|---:|---|
| complete historical cold (s) | 18.401 | 18.993 | 19.393 | <30 | pass |
| complete forecast cold (s) | 2.136 | 2.164 | 2.481 | <8 | pass |
| one-sheet parsed-cache restore (s) | 0.031 | 0.032 | 0.038 | <1 | pass |
| warm release listing (s) | 0.001 | 0.001 | 0.001 | <1 | pass |
| current view from parsed cache (s) | 0.443 | 0.443 | 0.447 | <1 | pass |
| series catalog from parsed cache (s) | 0.082 | 0.083 | 0.084 | <1 | pass |
| historical parsed-cache restore (s) | 0.350 | 0.351 | 0.354 | <1 | pass |
| historical peak RSS delta (MiB) | 418.266 | 482.188 | 528.859 | <300 | **fail** |

The run returned 105,228 historical observations, 1,385 series and all 44
historical data worksheets (plus the three classified metadata worksheets).

## Build and package checks

Independent source build:

```sh
R CMD build /path/to/user/dev/readreq
```

Result: `readreq_0.0.0.9000.tar.gz` built successfully with vignettes.

Independent ordinary built-package check:

```sh
R CMD check --no-manual readreq_0.0.0.9000.tar.gz
```

Result: `Status: OK`. Installation, dependencies, code analysis,
documentation, tests and vignette rebuild all passed. Repository-index
warnings from the network-restricted host did not become check warnings.

Independent CRAN-style built-package check:

```sh
_R_CHECK_CRAN_INCOMING_REMOTE_=false \
R CMD check --as-cran readreq_0.0.0.9000.tar.gz
```

Result: `Status: 1 WARNING, 3 NOTEs`.

- warning: host has no optional `qpdf`;
- note: development version and placeholder maintainer;
- note: host time could not be verified; and
- note: host HTML Tidy is too old for HTML validation.

There were no package-code, documentation, test, example, installation,
vignette or manual failures.

## API, evidence, licensing and repository contents

`NAMESPACE` contains the 19 exports listed in `PHASES_1_6_EVIDENCE.md`, and all
have generated reference documentation. Four required vignettes, cache guide,
supported-release matrix, attribution page, NEWS, contribution guide and code
of conduct are present.

`req_attribution()` correctly distinguishes the Department's CC BY 4.0 source
material from the package's MIT code licence and excludes the Coat of Arms,
trade marks and third-party material.

The only committed-style workbook fixtures are five 20–37 KiB synthetic
`.xlsx` files. Their hashes match the evidence. ZIP inspection found no media,
drawing, image, VBA or binary payloads. There are no PDFs, logos, raster/vector
images, `.xls` workbooks or official full workbooks in the package tree. The
only source file over 100 KiB is the text validation mapping CSV.

`PHASES_1_6_EVIDENCE.md` is comprehensive and candid about all four release
blockers. `PHASE0_EVIDENCE.md` remains an explicitly scoped historical Phase 0
record and should not be read as the current implementation state.

## Chartwell isolation

The pre-existing `/path/to/user/dev/data_viewer` status baseline was:

```text
20 entries
SHA-256(status --porcelain) =
77817dfe129e146f551b53074e956d892e7e76f767d95adb3ba733cb431c84cf
```

The post-review status has the same entry count and exact hash. No Chartwell
file was created or modified by this package implementation or review.

## Release recommendation

Do not tag `v0.1.0` or begin Chartwell integration yet. The next release gate
should require:

1. measured peak historical RSS below 300 MiB, or a documented program-manager
   decision changing that target;
2. real maintainer metadata and intended release version;
3. a reviewed commit pushed to a repository and recorded as the pinned
   integration identity;
4. a repeated CRAN-style check on a host with the required checking tools; and
5. a short follow-up independent review confirming only those release blockers
   changed and the functional gates remain green.
