# Decision 0001: Stage 0 dependencies

Status: accepted, 2026-07-27

Stage 0 uses base R only at runtime. `testthat (>= 3.0.0)` is suggested for the
offline contract suite. The implementation plan's proposed transport and parser
dependencies (`cli`, `digest`, `fs`, `httr2`, `readxl`, `rlang`, `rvest`,
`stringr`, `tibble`, `vctrs`, `xml2`) remain approved candidates and are added
only in the phase that uses them. This keeps the skeleton installable without
claiming parser behavior that does not yet exist.
