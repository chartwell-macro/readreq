# Troubleshooting

## Discovery or download fails

Check the condition class, requested release and cache directory. A
`req_release_discovery_error` concerns official page discovery;
`req_asset_missing_error` means the requested release lacks an admitted asset;
`req_download_error` concerns transport or an incomplete exact cache.

Retrying with `refresh = TRUE` refreshes discovery but never deletes an
existing raw snapshot.

## A workbook is rejected

`req_asset_format_error` indicates unexpected bytes.
`req_workbook_schema_error` or `req_sheet_parse_error` means the workbook no
longer matches an audited structural profile. Do not bypass the error by
renaming the file or dropping cells. Open a report with the release, sheet,
parser version and source hash.

## A period or unit is rejected

`req_period_parse_error` and `req_unit_conflict_error` prevent ambiguous
semantics. Include the raw header/unit and surrounding table labels in a
minimal synthetic reproduction.

## Current view fails

`req_stitch_conflict_error` means equal-priority source rows disagree. Use the
reported view to inspect both rows and update the versioned precedence policy
only with source evidence.

## Offline replay unexpectedly reaches the network

Confirm the exact release has all requested raw assets and that the same
`cache_dir` is used. A partial raw cache cannot satisfy an all-assets request.
Use `download_req_release()` while online to populate the missing roles.

## Reporting a problem

Follow `SUPPORT.md`. Do not attach official workbooks; provide exact URLs,
SHA-256 hashes, sheet/table labels and a reduced synthetic example.
