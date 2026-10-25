# Contributing to readreq

Thank you for helping improve `readreq`. Contributions are reviewed against
source fidelity, reproducibility and backwards compatibility rather than only
whether an example happens to run.

## Before opening a change

Use the [chartwellmacro@gmail.com](mailto:chartwellmacro@gmail.com)
for bugs, release-support requests, and API proposals. Security-sensitive
reports must follow `SECURITY.md` and must not disclose details publicly.

For a new release or parser profile, include:

- the exact official landing page and discovered asset roles;
- source hashes kept outside the repository;
- a structural fingerprint and reduced synthetic fixture;
- raw-cell goldens with workbook sheet and cell context;
- expected row, series and table counts;
- proof that unexplained numeric and missing-marker payload fails loudly; and
- the support-status decision and any `unsupported_reason`.

Do not commit official workbooks, report PDFs, logos, the Commonwealth Coat of
Arms, trademarks or third-party data.

Package code and package-authored synthetic fixtures are MIT-licensed,
copyright Chartwell Macro. Official publications, runtime-downloaded source data,
upstream code and third-party material retain their own rights and terms.

## Development workflow

1. Create a focused branch.
2. Keep discovery, download/cache and parsing concerns separate.
3. Add or update Rd help, vignettes and repository guides with code changes.
4. Add offline regression tests and reduced synthetic fixtures.
5. Run the checks below.
6. Explain public API, schema, cache-key and parser-version effects in the
   change description.

## Required checks

```sh
Rscript -e 'testthat::test_local(".", reporter = "summary")'
R CMD build .
R CMD check --no-manual readreq_0.1.0.tar.gz
```

Before a public release, also run:

```sh
_R_CHECK_CRAN_INCOMING_REMOTE_=false \
R CMD check --as-cran readreq_0.1.0.tar.gz
```

Live checks are optional for ordinary development and require explicit local
paths to approved official assets. To validate a newly supported release, set
all three fixture paths as well as the opt-in flag:

```sh
READREQ_LIVE_TESTS=true \
READREQ_JUNE_2026_FORECAST=/absolute/path/to/june-forecast.xlsx \
READREQ_JUNE_2026_HISTORICAL=/absolute/path/to/june-history.xlsx \
READREQ_DEC_2025_FORECAST=/absolute/path/to/december-forecast.xlsx \
Rscript -e \
  'testthat::test_local(".", reporter = "summary")'
```

## Compatibility rules

- Do not infer asset URLs from filename conventions.
- Do not identify worksheets by position alone.
- Do not turn missing, suppressed or confidential values into zero.
- Do not overwrite an existing raw content hash or parsed vintage.
- Do not collapse values across tables without a documented precedence rule.
- Do not change public columns, statuses or identities without a migration
  note and an appropriate version decision.
- Bump the parser/cache contract whenever stale cached output could mask a
  semantic change.

## Documentation style

Examples must be reproducible, avoid hidden network access and state when an
exact release is required. Use plain language, explain source terminology and
link to the official source page. New exported functions require an Rd page,
an API-map entry and at least one tested example or vignette use.

## Review expectations

Reviewers may ask for raw-cell evidence, adversarial workbook mutations or
independent reproduction. A parser change is not accepted solely because
`R CMD check` passes. See `GOVERNANCE.md` for decision and release ownership.
