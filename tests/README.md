# Age boundaries and published ONS reference

Run `python3 tests/test_age_bands.py` from the repository root. It executes
the production SQL CASE expressions for numeric fixture ages in SQLite after
replacing TRY_CAST with CAST, checks every boundary including age ten and 90+,
checks the older report's registered-age labels, and reconciles the published
England/Wales reference. This does not execute SQL Server, validate its handling
of nonnumeric ages, or replace an R render against the warehouse.

The focused loader now requires each age/sex extract to reconcile with its
national source total. The mid-2024 reference audit compares the database's
July 2024 snapshot with a fixed, sourced publication; differences may indicate
reference-year/vintage differences or warehouse coverage issues. It does not
overwrite database estimates or imply that a snapshot date proves the ONS year.

# Payment reduction and report tables

Run `Rscript tests/test_fixed_total_payment_rates.R` for the additional
comparison holding each geography's full payment total constant. Tests check
£165 versus £183.33 when £1,650,000 is divided by 10,000 registrations or
9,000 ONS residents, a lower average when ONS exceeds registrations, equal
populations, zero payments, undefined averages at zero ONS population, invalid
inputs, unrounded rates, and independence from the loss model's remaining pot.

The focused report retains all three payment-loss charts and adds national,
regional and April 2026 ICB average-payment charts, with expandable tables.
The added calculation uses the same practice registration and payment totals
as the loss model, and changes only the population denominator. Total payments
remain unchanged even when the ONS denominator is larger than registrations.

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

The coverage audit separates English codes absent from the IMD lookup from
codes present with missing/invalid deciles. Other/unassigned residence is
computed before the lookup and does not disappear when English IMD coverage
improves. The report shows an expandable code-level audit and the warehouse
IMD snapshot date, without claiming that the date identifies the index edition.
The IMD extract no longer uses MAX(decile) to conceal conflicting records;
exact duplicate records are removed, while conflicting LSOA keys fail validation.

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
