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
It retains the reference's 20 chart types and 16 comparison tables.
Word output uses that document's styles and page settings as its reference.
The additional source-audit tables are omitted from this clean report; the
coverage helper still provides the detailed audit for separate analysis.

| Comparison | Registered population source | Other input |
| --- | --- | --- |
| National, age, sex, region and ICB | Practice-level registrations | English LSOA ONS estimates |
| IMD deciles | English-resident LSOA registrations with valid IMD | English LSOA ONS estimates |
| Patients per qualified GP FTE | Practice-level registrations | Practice workforce |
| Both payment scenarios | Practice-level registrations | Practice annual payments |

All registration comparisons use practice data except IMD. Practice totals
include patients of English GP practices irrespective of residence; Welsh and
unknown LSOA codes are not excluded from those totals. Only the IMD analysis
uses LSOA residence counts and filters. The opening source reconciliation
continues to compare the two registration extracts.

Every figure embeds its source in the caption; tables identify it too.
Value-label text is neutral grey. Series colours remain. HTML tables start
collapsed; Word tables remain visible. Counts are calculated from the extracts,
so the changed population scope updates results rather than freezing the
attachment's numbers.

Welsh and other/unassigned residence codes are excluded from IMD denominators.
IMD additionally excludes English LSOAs without a valid decile. These residence
exclusions are not applied to practice-level charts or tables.
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
source; assigned practice registration totals may be smaller than the national
practice source, with the unassigned counts disclosed. Duplicate practice
geography keys and missing snapshot sources stop rendering.

