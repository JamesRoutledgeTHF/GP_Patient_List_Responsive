# Paper tables

Run `Rscript tests/test_paper_tables.R` from the repository root. The tests need
only base R and synthetic aggregate counts; they do not use database credentials.

They check residence partitions (including a missing residence code), demographic
coverage, absent LSOAs, incomplete deprivation and workforce linkage, percentage
denominators, and the shared unrounded FTE denominator. Missing counts, duplicate
keys, conflicting monthly workforce snapshots and inconsistent totals must fail.

`11_Build_Paper_Tables.R` builds Table 1 and Table 2 from the focused report's
existing data extracts. Render `05_Patient_List_Focused.Rmd` in the usual database
environment to populate the tables. Table 1 uses all-source totals for residence
and demographic percentages, and English-residence totals for deprivation.

LSOA age/sex data are not extracted, and practice registrations cannot identify
residence directly; the table marks these cells NE instead of assigning zero.
The workforce denominator is the existing partner/salaried FTE measure, not the
headline NHS fully qualified series. The IMD source snapshot is displayed, but
its edition still needs confirmation in the paper's Methods.
