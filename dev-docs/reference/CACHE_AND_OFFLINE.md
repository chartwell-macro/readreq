# Cache and offline operation

`req_cache_dir()` uses `tools::R_user_dir("readreq", "cache")`. Raw assets live
under `raw/<release_id>/<sha256>/<asset>` and are immutable. Downloads are
written to a temporary file, checked by byte signature and workbook
readability, hashed, then atomically promoted. Refreshing discovery never
deletes a raw snapshot.

Parsed cache keys include release, source hash, parser version, asset and
selection. Current-view artifacts are keyed by both workbook hashes, parser
version, requested data scope and current-policy version. Series-catalogue
artifacts use the same source identity. Writes are atomic, so a populated exact
release can restore a selected sheet, coherent current view or catalogue
without reparsing and without network access.

Local workbook paths can be passed directly to `read_req_forecasts()` and
`read_req_history()`.

Default tests are offline. Live checks require `READREQ_LIVE_TESTS=true`.
Cache pruning is explicit and never automatic.
