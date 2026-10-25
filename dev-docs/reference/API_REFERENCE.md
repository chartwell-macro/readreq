# API map

## Discovery and transport

| Function | Purpose |
|---|---|
| `list_req_releases()` | List all 59 audited editions and exact asset roles |
| `download_req_release()` | Cache selected raw assets immutably |
| `req_cache_dir()` | Return the user cache location |

## Readers

| Function | Purpose |
|---|---|
| `read_req()` | Read combined forecast/history data as reported or current |
| `read_req_forecasts()` | Read and filter forecast workbook tables |
| `read_req_history()` | Read and filter historical workbook tables |

## Catalogues and validation

| Function | Purpose |
|---|---|
| `req_series_catalog()` | List stable semantic series |
| `validate_req_release()` | Return release-level validation diagnostics |
| `req_source_catalog()` | Return the semantic source-table catalogue |
| `req_observation_schema()` | Return the observation contract |
| `req_release_manifest_schema()` | Return the release-manifest contract |
| `req_raw_asset_manifest_schema()` | Return the raw-asset contract |

## Vintages

| Function | Purpose |
|---|---|
| `compare_req_vintages()` | Run one or all supported comparison operations |
| `req_history_revision()` | Compare historical observations across releases |
| `req_forecast_revision()` | Compare forecast/projection vintages |
| `req_forecast_error()` | Compare an earlier forecast with a realisation |

## Controlled vocabularies and attribution

| Function | Purpose |
|---|---|
| `req_status()` | Return supported period statuses |
| `req_missing_reason()` | Return controlled missing-value reasons |
| `req_attribution()` | Return source and attribution guidance |

All exported functions have installed Rd help. Use `?function_name` for full
arguments, return values and condition behaviour.
