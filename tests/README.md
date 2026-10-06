# Payment reduction and report tables

Run `Rscript tests/test_payment_reduction.R` from the repository root. The
base R tests cover the £165-per-registration example, no loss where ONS equals
or exceeds registrations, zero payments, an unrounded rate, and invalid inputs.

`13_Model_Payment_Reduction.R` calculates a loss-only scenario using each
geography's own observed payment rate. Regional/ICB estimates are independent
of the national calculation and may not add up to it. This assumes all payment
categories change proportionately with the unweighted registered list; it does
not implement the actual GP contract.

The focused HTML report uses closed-by-default native `details` elements for
every table. Each summary can be activated with a mouse or keyboard. Word
output retains ordinary visible tables. The ONS age-trend audit uses July
snapshots, does not bridge gaps in years, and includes source LSOA counts.
Its discussion distinguishes supported census/migration context from unverified
causes of the particular curves in the database.

# Registration coverage

Run `Rscript tests/test_registration_coverage.R` from the repository root.
These base R fixtures check the practice-to-LSOA source difference, Welsh LSOA
and patient counts, other/unassigned residence, and additional English IMD
exclusions. The reductions must reconcile without counting Welsh registrations
twice. Missing counts and duplicate keys fail; a larger LSOA source total is
reported as an increase rather than described as a loss.

`12_Summarise_Registration_Coverage.R` calculates the opening narrative from
the original registration extracts. The report checks its final deprivation
total against the actual IMD analysis. Tables 1 and 2 are currently not rendered.

# Optional paper tables

Run `Rscript tests/test_paper_tables.R` from the repository root. The tests need
only base R and synthetic aggregate counts; they do not use database credentials.

They check residence partitions (including a missing residence code), demographic
coverage, absent LSOAs, incomplete deprivation and workforce linkage, percentage
denominators, and the shared unrounded FTE denominator. Missing counts, duplicate
keys, conflicting monthly workforce snapshots and inconsistent totals must fail.

`11_Build_Paper_Tables.R` and its tests are retained for optional future use.
It is not called by the current focused report. Render
`05_Patient_List_Focused.Rmd` in the usual database environment to populate the
opening coverage narrative. Table 1 uses all-source totals for residence
and demographic percentages, and English-residence totals for deprivation.

LSOA age/sex data are not extracted, and practice registrations cannot identify
residence directly; the table marks these cells NE instead of assigning zero.
The workforce denominator is the existing partner/salaried FTE measure, not the
headline NHS fully qualified series. The IMD source snapshot is displayed, but
its edition still needs confirmation in the paper's Methods.
