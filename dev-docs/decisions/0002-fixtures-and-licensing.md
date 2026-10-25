# Decision 0002: fixtures and licensing

Status: accepted, 2026-07-27

Committed fixtures will be **REDUCED/DERIVED synthetic, structurally faithful
fixtures only**. They may encode source-like workbook structures and known
failure modes but will not redistribute full official workbooks or reports.
They will contain no official logos, Commonwealth Coat of Arms, decorative
report content or third-party values.

Full official assets stay outside this repository. An opt-in regression
manifest may retain their official URLs and hashes without the bytes. Source
material is separately licensed. Package code and package-authored synthetic
fixtures are MIT-licensed, copyright Chartwell Macro; that package licence does not
grant rights over excluded material.

Documentation may include a rendered chart derived from official values when
the precise source, licence and exclusions have been verified and recorded
without committing the source workbook. `man/figures/time-series-chart-1.png`
is the only such exception: it visualises the June 2026 quarterly iron ore
export-volume history with forecast paths from the March 2024, March 2025 and
June 2026 REQ editions through the package's public readers. Each source
publication states CC BY 4.0 subject to named exclusions. The selected tables
credit ABS Cat. No. 5368.0, the Department of Industry, Science and Resources,
and other named sources; those source-stated exclusions and third-party rights
continue to apply. The chart contains no source logos, Coat of Arms or
decorative publication content. It is not covered by the package's MIT licence;
`inst/COPYRIGHTS` records the rights boundary.
