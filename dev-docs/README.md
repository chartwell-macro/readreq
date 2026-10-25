# Development documentation

This directory contains engineering material for `readreq`. It is excluded
from the built R package so the installed documentation remains compact.

- `reference/` contains engineering API, data-contract, cache, support and
  release documentation, including the documentation source map. Root
  community files and `CITATION.cff` are canonical; no separate policy or
  citation copies are maintained here.
- `evidence/` contains the complete release-output audit and validation
  artefacts.
- `decisions/` contains active architectural decisions.
- `archive/vignettes/` preserves historical development drafts; the installed
  articles under the package-root `vignettes/` directory are canonical.
- `scripts/` contains reproducible audit and benchmark utilities. The
  `render-official-chart.R` maintainer script regenerates the attributed iron
  ore history-and-vintages chart only when `READREQ_LIVE_DOCS=true`; normal
  package and documentation builds never download its source workbooks.
- `archive/` contains historical implementation plans and review records.

The package root `README.md`, installed help and release catalogue are the
authoritative statements of current support.
