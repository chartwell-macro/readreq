test_that("the checked-in REQ catalogue covers every actual edition", {
  releases <- list_req_releases()

  expect_equal(nrow(releases), 59L)
  expect_equal(length(unique(releases$release_id)), 59L)
  expect_true(all(releases$support_status == "supported"))
  expect_equal(
    releases$release_id[which.min(releases$release_date)],
    "req-2011-09"
  )
  expect_equal(
    releases$release_id[which.max(releases$release_date)],
    "req-2026-06"
  )

  report_only <- vapply(
    releases$asset_roles,
    function(roles) identical(roles, "report"),
    logical(1)
  )
  expect_equal(sum(report_only), 2L)
  expect_setequal(
    releases$release_id[report_only],
    c("req-2011-12", "req-2013-03")
  )
  expect_true(all(
    releases$support_note[report_only] == "audited report table fallback"
  ))
  expect_true(all(
    releases$support_note[!report_only] ==
      "audited structured companion data"
  ))
})
