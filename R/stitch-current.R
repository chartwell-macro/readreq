.req_current_policy_version <- "1"

req_stitch_current <- function(data) {
  if (!nrow(data)) return(data)
  current_key <- req_status_independent_key(data)
  duplicate_key <- duplicated(current_key) |
    duplicated(current_key, fromLast = TRUE)
  singles <- data[!duplicate_key, , drop = FALSE]
  if (!any(duplicate_key)) {
    attr(singles, "conflicts") <- data[FALSE, , drop = FALSE]
    return(singles)
  }

  duplicate_rows <- data.table::as.data.table(
    data[duplicate_key, , drop = FALSE]
  )
  duplicate_rows[, `.req_index` := .I]
  duplicate_rows[, `.req_key` := current_key[duplicate_key]]
  status_rank <- c(
    historical = 5L, estimate = 4L, forecast = 3L, projection = 2L,
    `published-unclassified` = 1L
  )
  duplicate_rows[, `.req_rank` := unname(status_rank[period_status])]
  duplicate_rows[is.na(.req_rank), `.req_rank` := 0L]
  duplicate_rows[, `.req_candidate` := .req_rank == max(.req_rank), by = .req_key]
  duplicate_rows[, `.req_source_priority` := .req_candidate & ifelse(
    period_status == "historical",
    source_dataset == "historical",
    source_dataset == "forecast"
  )]
  duplicate_rows[, `.req_role_priority` :=
    .req_candidate & record_role == "canonical"]
  duplicate_rows[, `.req_token` := paste(
    ifelse(is.na(value), "<missing>", format(value, digits = 17)),
    ifelse(is.na(missing_reason), "", missing_reason),
    sep = "\u001f"
  )]
  summary <- duplicate_rows[, .(
    candidate_n = sum(.req_candidate),
    source_priority_n = sum(.req_source_priority),
    role_priority_n = sum(.req_role_priority),
    candidate_token_n = data.table::uniqueN(.req_token[.req_candidate])
  ), by = .req_key]
  duplicate_rows <- summary[duplicate_rows, on = ".req_key"]

  role_choice <- duplicate_rows[
    role_priority_n == 1L & .req_role_priority,
    .req_index
  ]
  priority_choice <- duplicate_rows[
    role_priority_n != 1L &
      source_priority_n == 1L & .req_source_priority,
    .req_index
  ]
  equal_keys <- summary[
    role_priority_n != 1L &
      source_priority_n != 1L & candidate_token_n == 1L,
    .req_key
  ]
  equal_choice <- integer()
  if (length(equal_keys)) {
    equal_choice <- duplicate_rows[
      .req_key %in% equal_keys & .req_candidate
    ][
      order(source_dataset, table_id, source_sheet)
    ][
      , .(chosen = .req_index[[1L]]), by = .req_key
    ][["chosen"]]
  }
  resolved_keys <- unique(c(
    duplicate_rows$.req_key[
      duplicate_rows$.req_index %in% role_choice
    ],
    duplicate_rows$.req_key[
      duplicate_rows$.req_index %in% priority_choice
    ],
    equal_keys
  ))
  conflict_rows <- duplicate_rows[
    !.req_key %in% resolved_keys,
    .req_index
  ]

  duplicated_data <- data[duplicate_key, , drop = FALSE]
  resolved <- duplicated_data[
    c(role_choice, priority_choice, equal_choice), , drop = FALSE
  ]
  conflicts <- duplicated_data[conflict_rows, , drop = FALSE]
  if (nrow(conflicts)) conflicts$record_role <- "conflict"
  out <- rbind(singles, resolved, conflicts)
  rownames(out) <- NULL
  attr(out, "conflicts") <- conflicts
  out
}
