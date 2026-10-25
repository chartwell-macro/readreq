#' Default readreq cache directory
#'
#' @return A platform-appropriate cache path.
#' @examples
#' req_cache_dir()
#' @export
req_cache_dir <- function() {
  tools::R_user_dir("readreq", "cache")
}

.req_cache_path <- function(cache_dir, ...) {
  file.path(path.expand(cache_dir), ...)
}

.req_dir_create <- function(path) {
  if (!dir.exists(path) && !dir.create(path, recursive = TRUE, showWarnings = FALSE)) {
    req_abort(
      "req_validation_error",
      paste0("Could not create cache directory: ", path),
      product = "resources_energy_quarterly",
      remediation = "Choose a writable cache_dir and retry."
    )
  }
  invisible(path)
}

.req_atomic_write_raw <- function(bytes, path) {
  .req_dir_create(dirname(path))
  tmp <- tempfile(
    pattern = paste0(".", basename(path), "-"),
    tmpdir = dirname(path)
  )
  on.exit(if (file.exists(tmp)) unlink(tmp), add = TRUE)

  writeBin(bytes, tmp)

  if (!file.rename(tmp, path)) {
    req_abort(
      "req_validation_error",
      paste0("Atomic cache promotion failed for: ", path),
      product = "resources_energy_quarterly",
      remediation = "Check cache permissions and that the cache is on one filesystem."
    )
  }
  invisible(path)
}

.req_write_json_atomic <- function(x, path) {
  json <- jsonlite::toJSON(
    x,
    dataframe = "rows",
    Date = "ISO8601",
    POSIXt = "ISO8601",
    UTC = TRUE,
    na = "null",
    null = "null",
    auto_unbox = TRUE,
    pretty = TRUE
  )
  .req_atomic_write_raw(charToRaw(enc2utf8(json)), path)
}

.req_read_json <- function(path, simplify = TRUE) {
  if (!file.exists(path)) {
    return(NULL)
  }
  tryCatch(
    jsonlite::fromJSON(path, simplifyVector = simplify),
    error = function(e) {
      req_abort(
        "req_validation_error",
        paste0("Cached JSON is unreadable: ", path),
        product = "resources_energy_quarterly",
        remediation = "Remove only the named cache file and retry discovery.",
        parent = e
      )
    }
  )
}

.req_acquire_lock <- function(path, timeout = 30) {
  .req_dir_create(dirname(path))
  started <- Sys.time()
  repeat {
    if (dir.create(path, recursive = FALSE, showWarnings = FALSE)) {
      return(invisible(path))
    }
    if (as.numeric(difftime(Sys.time(), started, units = "secs")) >= timeout) {
      req_abort(
        "req_download_error",
        paste0("Timed out waiting for cache writer lock: ", path),
        product = "resources_energy_quarterly",
        remediation = "Wait for the other writer to finish, then retry."
      )
    }
    Sys.sleep(0.05)
  }
}

.req_release_lock <- function(path) {
  if (dir.exists(path)) {
    unlink(path, recursive = TRUE, force = TRUE)
  }
  invisible(NULL)
}

.req_with_lock <- function(path, code) {
  .req_acquire_lock(path)
  on.exit(.req_release_lock(path), add = TRUE)
  force(code)
}
