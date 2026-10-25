# Publication readiness

> Archived pre-0.1.0 checklist. Current support and certification evidence are
> recorded in `../reference/SUPPORTED_RELEASES.md`.

## Current decision

The supported parser scope and ordinary package checks pass independent
review. The repository is not yet approved for a public `v0.1.0` tag or
downstream integration.

## Open release blockers

1. Historical-workbook peak RSS exceeds the initial 300 MiB target.
2. `DESCRIPTION` contains an unconfirmed placeholder maintainer email.
3. A public repository URL, issue tracker and private security contact are not
   configured.
4. CRAN-style checking must be repeated on a fully provisioned host.

The first item requires either further engineering and remeasurement or an
explicit, documented target decision. It must not be silently removed from
the evidence.

## Completed gates

- all 59 audited releases pass;
- all 23 forecast and 47 historical sheets are classified;
- source goldens, counts, hashes and mappings reproduce;
- raw/cache immutability and offline replay pass;
- reported/current and all vintage operations pass;
- synthetic-fixture and licensing audits pass;
- ordinary source-package check is clean; and
- an implementation-independent reviewer reproduced the functional evidence.

See `INDEPENDENT_REVIEW.md` for the full review record.

## Documentation follow-up

The public documentation set was added on top of reviewed implementation
commit `1bd9ef1326e557b1a472b6c519b304bdec11009a`. It changes repository
guidance, package metadata, package-level help and citation files; it does not
change `R/`, parser fixtures or tests. After the documentation update, the
pkgdown site rendered all reference pages and vignettes, the installed
citation was evaluated, and an ordinary source-package check returned
`Status: OK`.
