# Focused report validation

Run the portable checks from the repository root:

```bash
python3 -m unittest discover -s tests -p 'test_*.py'
```

`test_age_bands.py` executes the production age CASE expressions for numeric
fixture ages in SQLite after replacing TRY_CAST with CAST. It checks boundaries
including age ten and 90+, the older report's age labels, and the sourced ONS
England/Wales reference. It does not test SQL Server nonnumeric casts.

`test_focused_lsoa_sources.py` executes the portable practice national and
snapshot SQL aggregates, and the unfiltered LSOA extract used for IMD, against
synthetic practice/residence records. It checks totals, date filtering, chart
provenance, source routing and constant-payment-before-loss chart order.
These checks do not execute R, SQL Server or the full report.

Run the existing base R checks in an R environment:

```bash
Rscript tests/test_registration_coverage.R
Rscript tests/test_payment_reduction.R
Rscript tests/test_fixed_total_payment_rates.R
Rscript tests/test_paper_tables.R
```

Coverage tests check practice-to-LSOA differences, disjoint Welsh/other residence
exclusions, additional English IMD loss, invalid counts and duplicate keys.
Payment tests check the £165 example, no reduction where ONS equals or exceeds
registrations, zero payments, unrounded rates and invalid inputs. Fixed-total
tests check unchanged budgets, including £165 versus £183.33 for different
denominators, undefined ONS rates at zero population and independence from the
loss scenario's remaining pot.

The optional paper-table helper and tests remain available; the focused report
does not call them or render Tables 1 and 2.

# Report sources and structure

Render `05_Patient_List_Focused.Rmd` with `rmarkdown::render()` in the existing
R and warehouse environment. Its layout follows
`05_Patient_List_Focused_Clean.docx`: disparities, population trends, July
snapshots, IMD, regions, ICBs, GP FTE, fixed-total payments, then payment loss.
It retains the reference's 20 chart types and 16 comparison tables, and adds
two deprivation trend charts, two funding loss-per-resident charts, one trend
coverage table and two funding-denominator tables.
Word output uses that document's styles and page settings as its reference.
The additional source-audit tables are omitted from this clean report; the
coverage helper still provides the detailed audit for separate analysis.

| Comparison | Registered population source | Other input |
| --- | --- | --- |
| National, age and sex | Practice-level registrations | English LSOA ONS estimates |
| Regional and ICB population comparisons | English-resident LSOA registrations | English LSOA ONS estimates |
| IMD deciles | English-resident LSOA registrations with valid IMD | English LSOA ONS estimates |
| Patients per qualified GP FTE | Practice-level registrations | Practice workforce |
| Both payment scenarios | Practice-level registrations | Practice annual payments |

IMD, regional and ICB population comparisons use residence-based LSOA data;
national/age/sex comparisons, GP FTE and funding analyses use practice data. Practice totals
include patients of English GP practices irrespective of residence; Welsh and
unknown LSOA codes are not excluded from those totals. The IMD, region and ICB population analyses use LSOA residence counts and
exclude Welsh/unknown residence. Missing English IMD additionally affects IMD. The opening source reconciliation
continues to compare the two registration extracts.

Every figure embeds its source in the caption; tables identify it too.
Value-label text is neutral grey. Series colours remain. HTML tables start
collapsed; Word tables remain visible. Counts are calculated from the extracts,
so the changed population scope updates results rather than freezing the
attachment's numbers.

Welsh and other/unassigned residence codes are excluded from the LSOA
population comparisons.
IMD additionally excludes English LSOAs without a valid decile. These residence exclusions are not applied to practice-level FTE or funding
charts and tables.
Practice-to-LSOA differences, residence exclusions and English IMD loss remain
separate. The IMD snapshot date does not by itself identify the index edition.

Local ONS populations use the official ONS April 2026 LSOA lookup, retaining
July 2024 counts. Practice registrations, workforce and payments use the
existing practice-to-2026-ICB map,
including nine documented historical postcode estimates for former Frimley
practices. See `data/README.md` for lookup provenance.

Registered-population denominators, workforce and payments follow practice
assignment; ONS denominators follow residence. Cross-boundary registration can
therefore affect comparisons. The payment scenarios are not contracted payment
predictions. Annual payment and population
dates are disclosed separately. Local losses use local rates and positive
differences and need not sum to the national estimate. Fixed-total averages
retain the full budget.

Render-time checks reconcile practice age/sex counts to practice totals and IMD
counts to the coverage helper. Local ONS totals reconcile to the national ONS
source, and the residence-based region/ICB registration charts reconcile to the
English LSOA registration total. Assigned practice registration totals may be
smaller than the national practice source, with the unassigned counts disclosed.
Duplicate practice
geography keys and missing snapshot sources stop rendering.


# Deprivation trends and population-normalised funding losses

Run `Rscript tests/test_imd_trends.R` to test the fixed-IMD balanced cohort,
decile-to-quintile grouping, count reconciliation, incomplete snapshots,
invalid IMD, duplicate records and invalid populations. Comparison tests cover
same-year July date alignment, missing source-years, zero denominators, signs,
percentage scaling and ambiguous duplicate snapshots. These are base R
fixtures; they require R but no warehouse connection.

`14_Summarise_IMD_Trends.R` groups deciles 1–2 into quintile 1 (most deprived)
through 9–10 into quintile 5 (least deprived). It retains English LSOAs present
in every available July snapshot of both registration and ONS histories with
a valid decile in the fixed latest warehouse IMD lookup. Both charts therefore
use the same constant LSOA set, and show cohort population counts, not full
England totals. The coverage table discloses excluded populations for each
source/date. Missing years are neither imputed nor connected by the plot.
The warehouse IMD snapshot date is shown; its edition is not inferred from it.
History queries begin at July 2015 independently of the rest of the report's
start date. Registrations use the legacy 2011-LSOA table before July 2024 and
the 2021-LSOA table from July 2024, with no overlap. The loader resolves exactly
one supported legacy table name from database metadata and stops if none or
multiple names are present. Actual historical availability must be checked in
the warehouse. Only codes shared across the histories and linked to the fixed
IMD lookup are retained; split/merged codes are excluded, not apportioned.
This common-code cohort does not constitute a full geography conversion.
Both figures mark July 2024 and break lines there to disclose the geography
and registration-source change.
The first chart combines both sources in panels by quintile; the
second compares quintiles using 100 × (registered − ONS) / ONS. Raw differences
and source counts are included in an expandable table. Comparisons match the
calendar year, permit different July snapshot days, and require both sources.
Unavailable years stay missing rather than becoming zero, and zero ONS counts
produce an undefined percentage.

The primary funding comparison is annual modelled loss divided by ONS residents
in each region or April 2026 ICB. Tables also give the practice registered count
and loss per registered patient. Populations are July 2024; payment dates remain
disclosed separately and are not newly fixed to a financial year. These ratios
adjust for population size, not geographic density. Funding models retain the
practice inputs, so cross-boundary registration remains a limitation.

`tests/test_payment_reduction.R` additionally checks the £165,000/9,000-resident
example, zero ONS population returning an undefined rate, and invariance of
per-person rates when payment and population totals are scaled together.


