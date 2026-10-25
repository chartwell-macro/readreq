# Phases 1–6 release-candidate evidence

> Archived milestone evidence. This document records the earlier nine-release
> implementation gate and is superseded by `../reference/SUPPORTED_RELEASES.md` and
> `../evidence/release-output-audit-final.csv`.

Date: 2026-07-27  
Package: `readreq` `0.0.0.9000`  
Parser contract: `1.2.0`  
Repository: local-only at `/path/to/user/dev/readreq`

## Acceptance state

The implementation is a Stage 3 package candidate, not a tagged `v0.1.0`
release. The source, offline tests, opt-in official-workbook regressions,
nine-release gate and timing targets pass. Independent review is complete and
recorded in `INDEPENDENT_REVIEW.md`. The repository remains local-only; the
coordinator will supply the reviewed local commit identity in the final
handoff, and no remote is claimed. The following release blockers remain
deliberately visible:

1. measured single-worker peak RSS is 436.5 MiB (three-run median 455.0 MiB),
   above the plan's 300 MiB target;
2. `DESCRIPTION` remains version `0.0.0.9000` and contains the placeholder
   maintainer email.

No tag or integration is recommended until those blockers are resolved or
explicitly accepted.

## Delivered public API

```text
compare_req_vintages()
download_req_release()
list_req_releases()
read_req()
read_req_forecasts()
read_req_history()
req_attribution()
req_cache_dir()
req_forecast_error()
req_forecast_revision()
req_history_revision()
req_missing_reason()
req_observation_schema()
req_raw_asset_manifest_schema()
req_release_manifest_schema()
req_series_catalog()
req_source_catalog()
req_status()
validate_req_release()
```

This is a new package, so the public API diff is the 19 exports above against
an empty baseline. `NAMESPACE` is the machine-readable source of truth.

## Functional coverage

### Transport and cache

- Discovery reads links and release identity from official landing-page
  metadata; it does not construct asset URLs from filename conventions.
- Forecast workbook, historical workbook and report PDF are snapshotted by
  SHA-256 in immutable content-addressed directories.
- Exact raw bytes can be replayed offline.
- Parsed workbook, selected-sheet, current-view and series-catalog caches
  include the relevant asset hashes, parser version, policy version and scope
  in their identities.
- Refresh adds new immutable objects; it never overwrites or deletes an old
  raw object.
- Workbook content is detected independently of the filename extension.
- Default tests make no network request. Live tests require
  `READREQ_LIVE_TESTS=true`.

### Parser and canonicalisation

- All 23 forecast worksheets classify; all 21 data worksheets parse.
- All 47 historical worksheets classify; all 44 data worksheets parse,
  including the six split labels `2(1)`, `2(2)`, `7(1)`, `7(2)`, `24(1)` and
  `24(2)`.
- Sheet order is not semantic: a fully shuffled workbook produces identical
  observations.
- Annual, quarterly and monthly grids are represented explicitly.
- Calendar, Australian financial year and month/quarter bases are source
  driven.
- `history`, `estimate`, `forecast`, `projection` and
  `published-unclassified` are explicit; no generic date-position inference is
  used.
- Missing/suppressed/confidential/non-numeric cells remain numeric `NA` with a
  controlled `missing_reason`; they are never converted to zero.
- Currencies, units, price basis, raw values, footnotes, source notes and
  third-party labels remain source-visible.
- A full-sheet disposition gate rejects numeric or missing-value-marker cells
  outside every recognised data/control block.
- The reported view preserves source presentations. The canonical/current
  policies retain provenance, classify reviewed redundant presentations as
  supporting, prefer completed history, and expose unresolved conflicts rather
  than silently choosing.
- Release identity comes from official landing-page metadata, not the internal
  workbook title. This catches the June 2026 historical `About`-sheet
  discrepancy.

## Fixture coverage and redistribution decision

Only reduced, derived, synthetic workbooks are committed. No official
workbook, logo, Coat of Arms, report page or decorative content is
redistributed.

| Fixture | SHA-256 | Coverage |
|---|---|---|
| `forecast-all-families.xlsx` | `c390e26f0cf039ce2ee7edd3e6c15f912a65769e11f28490a1a62e99f88984fc` | 23-sheet mapping, all forecast parser families, statuses, missing markers, notes and footnotes |
| `forecast-shuffled.xlsx` | `525d15f7ffacbd500921714d0bedb9d057e08b9f00475747a08531f4b9cbcec3` | order-independent classification |
| `historical-all-families-wrong-about.xlsx` | `94ee7b2ec24e6b691f197f1dc8be4c3315bc9a72ae219df679aa31c9d6c6e75a` | 47-sheet mapping, all historical families, split labels and bad internal release title |
| `forecast-unmapped-numeric.xlsx` | `f1e194628747e5e6ad0c8678ece288ecac9a5b3d7e47b40a66ae5dd9cafa84b0` | adversarial unclaimed numeric payload |
| `forecast-unmapped-marker.xlsx` | `f688edd1927a4a23425b78eacb402d8ed4f8e4fb68656b6634b9d636fd83eda8` | adversarial unclaimed missing/confidential marker |

The official workbooks used for live validation remain only in an external
content-addressed cache. The API exposes the required CC BY 4.0 attribution
and retains table-level source notes and third-party labels.

## Supported-release gate

All nine releases in that historical milestone passed the strict gate.
`Duplicate keys` are raw
within-workbook repeats; every one is resolved by an explicit canonical policy.
All releases have zero unresolved duplicate keys, zero current-view conflicts,
zero unknown units/currencies/statuses, zero unparsed data-like cells and zero
structural breaks.

| Release | Forecast rows / series | Historical rows / series | Duplicate keys / unresolved | Gate |
|---|---:|---:|---:|---|
| `req-2024-03` | 2,876 / 882 | 100,303 / 1,873 | 64 / 0 | valid |
| `req-2024-06` | 2,376 / 1,122 | 101,057 / 1,877 | 82 / 0 | valid |
| `req-2024-09` | 2,301 / 997 | 101,245 / 1,557 | 18 / 0 | valid |
| `req-2024-12` | 2,305 / 1,268 | 102,538 / 1,877 | 82 / 0 | valid |
| `req-2025-03` | 3,076 / 1,116 | 102,651 / 1,879 | 22 / 0 | valid |
| `req-2025-06` | 2,343 / 1,125 | 102,259 / 1,385 | 18 / 0 | valid |
| `req-2025-09` | 2,361 / 988 | 103,179 / 1,384 | 18 / 0 | valid |
| `req-2025-12` | 2,362 / 1,250 | 103,796 / 1,384 | 18 / 0 | valid |
| `req-2026-06` | 3,013 / 1,066 | 105,228 / 1,385 | 0 / 0 | valid |

Machine-readable evidence:

- `dev-docs/evidence/legacy-validation/supported-release-validation.csv`: release metadata,
  exact three-asset hashes, byte sizes, counts and all gate diagnostics;
- `dev-docs/evidence/legacy-validation/supported-release-sheet-mapping.csv`: 630 mapping rows,
  covering 23 forecast and 47 historical worksheets for each of nine releases;
- `dev-docs/evidence/legacy-validation/supported-release-table-counts.csv`: 585
  release/table/dataset count rows.

The all-nine sweep was produced with:

```sh
Rscript dev-docs/scripts/validate-supported-releases.R /tmp/readreq-supported-cache
```

Final summary:

```text
req-2026-06 valid forecast=3013/1066 history=105228/1385
req-2025-12 valid forecast=2362/1250 history=103796/1384
req-2025-09 valid forecast=2361/988  history=103179/1384
req-2025-06 valid forecast=2343/1125 history=102259/1385
req-2025-03 valid forecast=3076/1116 history=102651/1879
req-2024-12 valid forecast=2305/1268 history=102538/1877
req-2024-09 valid forecast=2301/997  history=101245/1557
req-2024-06 valid forecast=2376/1122 history=101057/1877
req-2024-03 valid forecast=2876/882  history=100303/1873
all releases: unresolved duplicates=0, current conflicts=0,
unknown semantic values=0, unparsed data-like cells=0, structural breaks=0
```

The subsequent parser marker change from `1.1.0` to `1.2.0` invalidates old
parsed caches. It did not alter workbook parsing semantics; the full offline
and official-workbook regression suites below ran after that marker change.

## Official-cell golden comparisons

The goldens are exact values transcribed from the reviewed official workbook
cells and asserted against returned canonical observations:

| Release / table / period | Concept | Official value | Returned value |
|---|---|---:|---:|
| Dec 2025, Commodity sector, 2025–26 | resource and energy export value | 382,959.866395418 A$m | 382,959.866395418 A$m |
| Jun 2026, Commodity sector, 2025–26 | resource and energy export value | 404,920.368456527 A$m | 404,920.368456527 A$m |
| Jun 2026 historical, Aluminium, 1990-Q1 | smelter/refinery alumina production | 2,753.228 | 2,753.228 |
| Jun 2026 historical, Aluminium, 1990-Q1 | alumina exports quantity | 2,099.76942 | 2,099.76942 |
| Jun 2026 historical, Aluminium, 1990-Q1 | alumina price | 400 | 400 |
| Jun 2026 historical, Gemstones, 1990-Q1 | sorted gem diamond exports | 254.743 | 254.743 |
| Jun 2026 historical, Gemstones, 1990-Q1 | sorted gem diamond imports | 49.347 | 49.347 |
| Jun 2026 forecast, Uranium, 2025 | Russia production | 3.06628442377136 | 3.06628442377136 |
| Jun 2026 forecast, Uranium, 2025 | Russia consumption | 7.06880323728 | 7.06880323728 |

The June total is explicitly `estimate`, with
`status_source = "landing-page"` and the reviewed landing-page statement in
`source_note`. The exact Dec-to-June revision is:

```text
old_value:          382959.866395418
new_value:          404920.368456527
absolute_change:     21960.502061109
status_transition:   forecast -> estimate
old_issue_date:      2025-12-19
new_issue_date:      2026-07-03
```

The June lithium result also contains exactly seven `kt LCE` observations;
footnote codes are retained separately rather than leaking into the unit.

## Tests

Offline suite:

```sh
Rscript -e 'pkgload::load_all(".", quiet=TRUE); testthat::test_dir("tests/testthat", reporter="summary")'
```

Output:

```text
contracts: ....................
current-and-vintages: .........................
live-validation: S
parser-families: ...........................................
phase1-transport: ....................................................

Skipped:
opt-in official workbook regression goldens hold
Reason: READREQ_LIVE_TESTS is not "true"

DONE
```

Result: 140 expectations passed, zero failures or warnings, one intentional
live-test skip.

Opt-in official-workbook suite:

```sh
READREQ_LIVE_TESTS=true \
READREQ_JUNE_2026_FORECAST=/tmp/readreq-supported-cache/raw/req-2026-06/011d09f15d401830845bf9abf13b3bd2e0baf4bc95ea647bdd03246fe83b01fa/forecast.xlsx \
READREQ_JUNE_2026_HISTORICAL=/tmp/readreq-supported-cache/raw/req-2026-06/d78ba67562f90fd42a137910ed4839aa259a29290ea609b406abe94455ccfc77/historical.xlsx \
READREQ_DEC_2025_FORECAST=/tmp/readreq-supported-cache/raw/req-2025-12/c7f255c199934229beb55788f0f74fc094a579fc7b00b748784c0aafdcb17c51/forecast.xlsx \
Rscript -e 'pkgload::load_all(".", quiet=TRUE); testthat::test_file("tests/testthat/test-live-validation.R", reporter="summary")'
```

Output:

```text
live-validation: .......................
DONE
```

Result: 23 expectations passed, zero failures, warnings or skips.

## Performance

Three clean cold repetitions and three cache restores were measured against
the 3.60 MB June 2026 historical workbook (105,228 observations, 1,385
series, 44 data sheets) and 0.89 MB forecast workbook. RSS is the delta above
the pre-parse child-process-tree baseline.

```sh
Rscript dev-docs/scripts/benchmark-release.R \
  /tmp/readreq-supported-cache/raw/req-2026-06/011d09f15d401830845bf9abf13b3bd2e0baf4bc95ea647bdd03246fe83b01fa/forecast.xlsx \
  /tmp/readreq-supported-cache/raw/req-2026-06/d78ba67562f90fd42a137910ed4839aa259a29290ea609b406abe94455ccfc77/historical.xlsx \
  /tmp/readreq-supported-cache
```

| Benchmark | Min | Median | Max | Unit |
|---|---:|---:|---:|---|
| complete historical cold | 18.875 | 19.707 | 19.961 | seconds |
| complete forecast cold | 2.120 | 2.158 | 2.580 | seconds |
| one-sheet parsed-cache restore | 0.031 | 0.032 | 0.039 | seconds |
| warm release listing | 0.001 | 0.001 | 0.001 | seconds |
| current view from parsed cache | 0.432 | 0.433 | 0.434 | seconds |
| series catalog from parsed cache | 0.085 | 0.085 | 0.090 | seconds |
| historical parsed-cache restore | 0.354 | 0.360 | 0.369 | seconds |
| historical peak RSS delta | 428.563 | 455.016 | 489.844 | MiB |

Cold timing meets the plan's 30-second historical target. The RSS target does
not pass.

Worker scaling:

```sh
Rscript dev-docs/scripts/benchmark-workers.R \
  /tmp/readreq-supported-cache/raw/req-2026-06/d78ba67562f90fd42a137910ed4839aa259a29290ea609b406abe94455ccfc77/historical.xlsx
```

```text
 workers cold_seconds peak_rss_delta_mib   rows
       1       19.368            436.500 105228
       2       11.255           1023.234 105228
```

Two workers improve elapsed time but more than double memory, so one worker is
the safe default.

## Build and package check

```sh
Rscript -e 'roxygen2::roxygenise()'
R CMD build /path/to/user/dev/readreq
_R_CHECK_CRAN_INCOMING_REMOTE_=false \
  R CMD check --as-cran /tmp/readreq_0.0.0.9000.tar.gz
```

Build output:

```text
* checking DESCRIPTION meta-information ... OK
* installing the package to build vignettes
* creating vignettes ... OK
* building ‘readreq_0.0.0.9000.tar.gz’
```

CRAN-style check output:

```text
* checking package dependencies ... OK
* checking whether package ‘readreq’ can be installed ... OK
* checking code files for non-ASCII characters ... OK
* checking R files for syntax errors ... OK
* checking dependencies in R code ... OK
* checking R code for possible problems ... OK
* checking Rd files ... OK
* checking for missing documentation entries ... OK
* checking for code/documentation mismatches ... OK
* checking tests ...
  Running ‘testthat.R’
 OK
* checking package vignettes ... OK
* checking re-building of vignette outputs ... OK
* checking PDF version of manual ... OK
* DONE

Status: 1 WARNING, 3 NOTEs
```

The warning is solely that the host lacks the optional `qpdf` executable for
PDF size-reduction checks. The three NOTEs are the intentional development
version/placeholder maintainer metadata, inability to verify the host clock,
and the host's old HTML Tidy. The package-code NOTE present in an earlier
check (`na.omit`) was fixed and is absent from this final check. Remote
incoming metadata was disabled because the execution environment restricts
network access; all dependency checks still passed.

The ordinary built-package check is clean:

```sh
_R_CHECK_CRAN_INCOMING_=false _R_CHECK_FORCE_SUGGESTS_=false \
  R CMD check --no-manual /tmp/readreq_0.0.0.9000.tar.gz
```

```text
* checking package dependencies ... OK
* checking whether package ‘readreq’ can be installed ... OK
* checking R code for possible problems ... OK
* checking for missing documentation entries ... OK
* checking for code/documentation mismatches ... OK
* checking tests ...
  Running ‘testthat.R’
 OK
* checking package vignettes ... OK
* checking re-building of vignette outputs ... OK
* DONE

Status: OK
```

## Unsupported and intentionally absent scope

- The official index contains no March 2026 edition; no release is invented.
- Pages exposed for 2021–2023 are `discovered-unverified` until their complete
  three-asset bundles and parser mappings receive the same audit.
- Trove-only and legacy-site releases are unsupported in this candidate.
- PDF report content is cached for provenance but is not parsed when a
  structured workbook source exists.
- Official report decoration, logos, Coat of Arms and workbook bytes are not
  bundled.
- Chartwell registration, source-catalogue edits, chart definitions and
  provider integration are intentionally absent.

## Chartwell isolation

All implementation paths are under `/path/to/user/dev/readreq`. No
package command writes into `/path/to/user/dev/data_viewer`; integration
is a separate future program. The program manager owns the before/after
comparison of the pre-existing Chartwell worktree status.

## Reproduction checklist

An independent reviewer should:

1. compare `NAMESPACE` with the 19-export list above;
2. run the offline and opt-in official-workbook suites exactly as shown;
3. inspect the official cells covered by `test-live-validation.R`;
4. review the three machine-readable validation reports;
5. rerun both benchmark tools;
6. confirm only synthetic `.xlsx` files exist inside the repository;
7. run the built-package CRAN-style check;
8. verify the Chartwell worktree baseline is unchanged by package work.
