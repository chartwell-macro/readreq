.req_default_transport <- function(url, mode = c("text", "file"), path = NULL) {
  mode <- match.arg(mode)
  local_path <- if (startsWith(url, "file://")) {
    utils::URLdecode(sub("^file://", "", url))
  } else if (file.exists(url)) {
    url
  } else {
    NA_character_
  }
  if (!is.na(local_path)) {
    local_path <- normalizePath(local_path, winslash = "/", mustWork = TRUE)
    if (identical(mode, "text")) {
      return(list(
        body = paste(readLines(local_path, warn = FALSE), collapse = "\n"),
        content_type = "text/html",
        status_code = 200L,
        final_url = local_path
      ))
    }
    if (is.null(path) || !nzchar(path) ||
        !file.copy(local_path, path, overwrite = TRUE)) {
      stop("Could not copy the supplied local asset.", call. = FALSE)
    }
    extension <- tolower(tools::file_ext(local_path))
    content_type <- switch(
      extension,
      pdf = "application/pdf",
      xlsx = paste0(
        "application/vnd.openxmlformats-officedocument.",
        "spreadsheetml.sheet"
      ),
      xls = "application/vnd.ms-excel",
      "application/octet-stream"
    )
    return(list(
      content_type = content_type,
      status_code = 200L,
      final_url = local_path
    ))
  }

  request <- httr2::request(url)
  version <- tryCatch(
    as.character(utils::packageVersion("readreq")),
    error = function(e) "0.1.0"
  )
  request <- httr2::req_user_agent(
    request,
    paste0("readreq/", version)
  )
  request <- httr2::req_timeout(request, seconds = 60)
  request <- httr2::req_retry(request, max_tries = 3)

  response <- if (identical(mode, "file")) {
    if (is.null(path) || !nzchar(path)) {
      stop("A destination path is required for file transport.", call. = FALSE)
    }
    httr2::req_perform(request, path = path)
  } else {
    httr2::req_perform(request)
  }

  headers <- httr2::resp_headers(response)
  list(
    body = if (identical(mode, "text")) {
      httr2::resp_body_string(response)
    } else {
      NULL
    },
    content_type = unname(.req_or(headers[["content-type"]], NA_character_)),
    etag = unname(.req_or(headers[["etag"]], NA_character_)),
    last_modified = unname(.req_or(
      headers[["last-modified"]],
      NA_character_
    )),
    content_disposition = unname(
      .req_or(headers[["content-disposition"]], NA_character_)
    ),
    status_code = httr2::resp_status(response),
    final_url = httr2::resp_url(response)
  )
}

.req_transport <- function(url, mode = c("text", "file"), path = NULL) {
  mode <- match.arg(mode)
  transport <- getOption("readreq.transport", .req_default_transport)
  if (!is.function(transport)) {
    stop("Option 'readreq.transport' must be a function.", call. = FALSE)
  }

  result <- transport(url = url, mode = mode, path = path)
  if (!is.list(result)) {
    stop("The readreq transport must return a named list.", call. = FALSE)
  }
  if (identical(mode, "text") &&
      (!is.character(result$body) || length(result$body) != 1L)) {
    stop("Text transport did not return a single response body.", call. = FALSE)
  }
  if (identical(mode, "file") &&
      (is.null(path) || !file.exists(path))) {
    stop("File transport did not create the requested destination.", call. = FALSE)
  }

  defaults <- list(
    body = NULL,
    content_type = NA_character_,
    etag = NA_character_,
    last_modified = NA_character_,
    content_disposition = NA_character_,
    status_code = 200L,
    final_url = url
  )
  utils::modifyList(defaults, result)
}

.req_or <- function(x, y) {
  if (is.null(x) || length(x) == 0L) y else x
}
