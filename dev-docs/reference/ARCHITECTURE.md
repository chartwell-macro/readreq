# Architecture

`readreq` separates source discovery, transport, parsing and analysis so an
offline parser never depends on live network state.

```text
official index
    -> exact release-page discovery
    -> release manifest
    -> verified immutable raw assets
    -> workbook classification and parsing
    -> reported observations
    -> canonical/current policy
    -> validation, catalogues and vintage comparisons
```

## Discovery

Release identity and asset URLs come from official page metadata. Missing
quarterly editions are preserved as gaps. Discovery produces a versioned
manifest and does not parse workbooks.

## Transport and cache

Downloads are staged, signature-checked, hashed and atomically promoted into a
content-addressed cache. Refreshing discovery cannot overwrite an existing raw
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
errors operate on the stable observation contract. They do not redownload or
reinterpret raw assets.
