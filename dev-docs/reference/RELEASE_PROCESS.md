# Release process

## Metadata

- Confirm version, maintainer name and monitored email.
- Add the public repository URL and `BugReports` URL to `DESCRIPTION`.
- Verify the repository's documented security-reporting route is available.
- Update `CITATION.cff`, `inst/CITATION`, `NEWS.md` and support policies.

## Source and parser evidence

- Audit every newly supported official release.
- Record exact landing pages, asset roles and SHA-256 hashes.
- Update sheet/table mappings, row/series counts and raw-cell goldens.
- Run current-view conflict and structural-break reports.
- Bump the parser/cache contract when semantics or cached output change.

## Licensing and fixtures

- Reconfirm official attribution and third-party exclusions.
- Verify committed fixtures are reduced synthetic artifacts.
- Scan fixtures for media, logos, macros and official workbook hashes.

## Verification

```sh
Rscript -e 'testthat::test_local(".", reporter = "summary")'
R CMD build .
R CMD check --no-manual readreq_<version>.tar.gz
R CMD check --as-cran readreq_<version>.tar.gz
```

Also run live official-workbook regressions, three cold/warm benchmark
repetitions, peak-RSS measurement and independent evidence reproduction.

## Documentation and website

- Render every vignette and example.
- Build the pkgdown site with `pkgdown::build_site()`.
- Check internal and external links.
- Confirm the API map, supported releases and troubleshooting guide match the
  release.

## Publish

Create an immutable signed or annotated tag only after all gates pass. Record
the commit and artifact hash, publish release notes and never move the tag.
