# Architecture

`readreq` separates release metadata, transport, parsing and analysis so an
offline parser never depends on live network state.

```text
audited installed catalogue
    -> exact release manifest row
    -> verified immutable raw assets
    -> workbook classification and parsing
    -> reported observations
    -> canonical/current policy
    -> validation, catalogues and vintage comparisons
```

## Release metadata

Release identity and asset URLs are recorded from official page metadata in a
versioned installed catalogue. Missing quarterly editions are preserved as
gaps. `list_req_releases()` reads this catalogue without network access and
does not parse workbooks; internal discovery tooling is not its runtime path.

## Transport and cache

Downloads are staged, signature-checked, hashed and atomically promoted into a
content-addressed cache. Refreshing an asset cannot overwrite an existing raw
hash. Exact cached releases are replayable without network access.

## Parsing

Parsers accept local files and classify sheets using titles plus structural
fingerprints. They account for every data-like cell in an admitted grid.
Unrecognised numeric or provider-marker payload fails closed.

## Normalisation and views

Shared contracts normalise time, status, missingness, units and semantic
series. Source-faithful reported observations remain available. Canonical and
current views apply versioned policies and retain their source rows.

## Analysis

Validation artifacts, series catalogues, revision operations and forecast
errors operate on the stable observation contract. They remain offline when
given parsed data, local inputs, or a complete exact cache; otherwise the
public wrappers can retrieve and parse the assets required by the request.
