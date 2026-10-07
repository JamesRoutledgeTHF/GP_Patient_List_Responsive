# Focused report validation

Run the portable checks from the repository root:

```bash
python3 -m unittest discover -s tests -p 'test_*.py'
```

`test_age_bands.py` executes the production age CASE expressions for numeric
fixture ages in SQLite after replacing TRY_CAST with CAST. It checks boundaries
including age ten and 90+, the older report's age labels, and the sourced ONS
England/Wales reference. It does not test SQL Server nonnumeric casts.

`test_focused_lsoa_sources.py` executes the portable national and sex SQL
aggregates against synthetic English, Welsh, OTHER and missing-residence records.
It checks sex reconciliation, unfiltered source totals, date filtering, chart
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
It retains the reference's 20 chart types and 16 comparison tables.
Word output uses that document's styles and page settings as its reference.
The additional source-audit tables are omitted from this clean report; the
coverage helper still provides the detailed audit for separate analysis.

| Comparison | Registered population source | Other input |
| --- | --- | --- |
| National, sex, IMD, region and ICB | English-resident LSOA registrations | English LSOA ONS estimates |
| Age and age-and-sex | Practice single-age registrations, all residence codes | English LSOA ONS estimates |
| Patients per qualified GP FTE | English-resident LSOA registrations | Practice workforce |
| Both payment scenarios | English-resident LSOA registrations | Practice annual payments |

The NHS LSOA release provides sex but no ages:
https://digital.nhs.uk/data-and-information/publications/statistical/patients-registered-at-a-gp-practice/metadata
Age charts remain explicitly labelled practice-data exceptions, with no inferred
age counts. All other registration comparisons use LSOA counts. Practice totals
are otherwise used only for the introductory source reconciliation.

Every figure embeds its source in the caption; tables identify it too.
Value-label text is neutral grey. Series colours remain. HTML tables start
collapsed; Word tables remain visible. Counts are calculated from the extracts,
so the changed population scope updates results rather than freezing the
attachment's numbers.

Welsh and other/unassigned residence codes are excluded from all LSOA comparison
denominators. IMD additionally excludes English LSOAs without a valid decile;
such codes remain in region/ICB comparisons when their geography is known.
Practice-to-LSOA differences, residence exclusions and English IMD loss remain
separate. The IMD snapshot date does not by itself identify the index edition.

Local populations use the official ONS April 2026 lookup, retaining July 2024
counts. Practice workforce/payments use the existing practice-to-2026-ICB map,
including nine documented historical postcode estimates for former Frimley
practices. See `data/README.md` for lookup provenance.

Population denominators follow residence; workforce/payments follow practice
assignment. These are population-to-resource comparisons, not actual practice
workload or contracted payment predictions. Annual payment and population
dates are disclosed separately. Local losses use local rates and positive
differences and need not sum to the national estimate. Fixed-total averages
retain the full budget.

Render-time checks reconcile practice age/sex counts to practice totals, LSOA
sex counts to English LSOA totals, national LSOA snapshots to region/ICB totals,
and IMD counts to the coverage helper. They stop on missing snapshot sources.
