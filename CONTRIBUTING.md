# Contributing to readreq

`readreq` makes the official Australian Resources and Energy Quarterly (REQ)
release history discoverable, cacheable, parseable and comparable. Changes are
reviewed for reproducibility, source fidelity and preservation of the package's
public contracts as well as for whether the code runs locally.

## Before reporting a problem or opening a pull request

Please email [chartwellmacro@gmail.com](mailto:chartwellmacro@gmail.com) before substantial changes and keep each change focused. For a parser,
catalogue or transport change, use the exact official REQ release and asset
information that motivated it. Do not commit credentials, private cache
contents, official workbooks or reports, logos, the Commonwealth Coat of Arms,
trademarks or third-party material. The small files under
`tests/testthat/fixtures/` are reduced test fixtures; do not replace them with
downloaded production data.

Source-data rights are edition-specific. Check the terms attached to the
particular official release before copying, redistributing or quoting source
material. `req_attribution()` provides guidance for supported data; it does not
make every source asset available under one blanket licence.

Package code and package-authored synthetic fixtures are MIT-licensed,
copyright Chartwell Macro. Official publications, runtime-downloaded source data,
upstream code and third-party material retain their own rights and terms.

## Reproducible reports

For a bug, include enough information to reproduce it without access to your
machine or credentials:

- `readreq` version or commit, R version, platform and `sessionInfo()`;
- the exact `release_id` (or local fixture path), requested view and selection
  arguments;
- the official source landing page and asset URL, when a downloaded asset is
  involved, plus its SHA-256 hash if available;
- whether the raw or parsed asset was already in the `readreq` cache, and
  whether the reproduction succeeds with a fresh temporary cache;
- a short runnable example and the expected and observed result; and
- the complete typed error class/message and warnings, with local paths,
  credentials and other sensitive values redacted.

For a source-catalogue or release issue, cite the official edition page and
describe the asset role, table or metadata that is missing or incorrect. Do not
upload an official workbook or report to an issue; a URL and hash are usually
the safer and more useful evidence.

## Local development

Edit roxygen comments in `R/` when changing user-facing help, then regenerate
the tracked help and namespace files with `roxygen2::roxygenise(".")`. The
default tests use the bundled reduced fixtures and do not require the network:

```sh
Rscript -e 'testthat::test_local(".", reporter = "summary")'
R CMD build .
R CMD check --as-cran readreq_*.tar.gz
```

Live source validation is deliberately opt-in, requires maintainer-approved
local source files, and should not be required for a normal pull request:

```sh
READREQ_LIVE_TESTS=true \
READREQ_JUNE_2026_FORECAST=/absolute/path/to/june-forecast.xlsx \
READREQ_JUNE_2026_HISTORICAL=/absolute/path/to/june-history.xlsx \
READREQ_DEC_2025_FORECAST=/absolute/path/to/december-forecast.xlsx \
Rscript -e \
  'testthat::test_local(".", reporter = "summary")'
```

Keep examples, tests and vignettes deterministic, bounded and suitable for
offline or changed-source conditions. Use temporary directories for test
artifacts and never write to a user's home directory or a shared cache.

## Compatibility and review expectations

The release catalogue, observation schemas, public columns, identities, status
values, classes, attributes, errors, cache keys and parser-version semantics
are compatibility surfaces. Do not change a frozen schema or other public
behavior without first emailing a proposal that explains the migration and
obtaining maintainer agreement. Avoid changing defaults, source-selection
rules or cache behavior as a side effect of cleanup.

Pull requests should explain the affected user workflow and include focused
offline regression tests. Reviewers may ask for raw-cell context, adversarial
fixture mutations, source evidence or a before/after contract comparison. A
successful `R CMD check` is necessary but is not, by itself, evidence that a
parser still represents the official source correctly.
