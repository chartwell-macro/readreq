# Phase 0 evidence

Date: 2026-07-27  
Scope: skeleton and contract freeze only

## Authoritative inputs

- `IMPLEMENTATION_PLAN.md` was read in full and left unchanged.
- `dev-docs/reference/shared_conventions.md` reconciles the plan's observation schema with
  `readagau` while preserving all plan-required fields.

## Frozen decisions

- Status: `s` estimate, `f` forecast, `z` projection; no date-position
  inference.
- Missing values: retained as numeric `NA` with raw value and controlled
  reason; never zero.
- Release and asset identities: official metadata plus SHA-256, not filenames
  or workbook titles.
- Cache: atomic, content-addressed and immutable; refresh never deletes raw.
- Vintage APIs: separate history revision, forecast revision and forecast
  error signatures; first realisation remains distinct from latest revised.
- Fixtures: reduced/derived synthetic structurally faithful only.

## Catalogue evidence

- Forecast: 23 rows and 23 unique semantic IDs.
- Historical: 47 rows and 47 unique semantic IDs.
- A direct June 2026 workbook audit resolves the count as three metadata sheets
  plus Tables 1–41, with Tables 2, 7 and 24 split across `(1)` and `(2)`
  worksheets. The catalogue preserves the observed non-numeric order around
  Tables 32–35 rather than sorting by table number.

## Intentional exclusions

No discovery network calls, downloads, workbook parsers, current-view
canonicalisation or comparison calculations are implemented. The exported
vintage functions are typed Stage 0 stubs whose signatures are frozen.

## Validation commands

Run:

```sh
Rscript -e 'testthat::test_local("/path/to/user/dev/readreq")'
R CMD build /path/to/user/dev/readreq
R CMD check --no-manual readreq_0.0.0.9000.tar.gz
```

Actual output is recorded at the end of this file after execution.

## Chartwell isolation

No file under `/path/to/user/dev/data_viewer` is created or modified by
this package work. The exact before/after `git status --porcelain` comparison is
recorded after validation.

## Actual validation output

```text
testthat::test_local:
contracts: .................
DONE

R CMD build:
* checking DESCRIPTION meta-information ... OK
* building ‘readreq_0.0.0.9000.tar.gz’

R CMD check --no-manual --no-vignettes:
* checking tests ...
  Running ‘testthat.R’
 OK
* DONE
Status: OK

catalogue:
readreq rows: 70 forecast: 23 historical: 47 unique IDs: 70

shared convention SHA-256:
bce518693242c6987edc7a9d93f23cdd7b09e4feb5353b1078f696808b1a7c83
```

The check emitted transient repository-index access messages from the
network-restricted environment while dependency metadata was checked; these
did not produce a package NOTE, WARNING or ERROR. The final check status is
`OK`.

The post-validation Chartwell `git status --porcelain` is byte-for-byte
identical to the pre-existing baseline captured before package work.
