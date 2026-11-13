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
Rscript tests/test_region_imd_quintiles.R
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
The report contains 27 charts, including the regional IMD quintile snapshot,
the ICB decile map and the two funding loss-per-resident charts. The removed
IMD quintile time-series charts and their comparison/coverage tables are no
longer rendered.
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


# Population-normalised funding losses

The primary funding comparison is annual modelled loss divided by ONS residents
in each region or April 2026 ICB. Tables also give the practice registered count
and loss per registered patient. Populations are July 2024; payment dates remain
disclosed separately and are not newly fixed to a financial year. These ratios
adjust for population size, not geographic density. Funding models retain the
practice inputs, so cross-boundary registration remains a limitation.

`tests/test_payment_reduction.R` additionally checks the £165,000/9,000-resident
example, zero ONS population returning an undefined rate, and invariance of
per-person rates when payment and population totals are scaled together.



## November 2026 chart changes

The focused report requests histories from July 2013. Actual first/last snapshots
are disclosed in the report; unavailable registration or workforce years are not
invented. Age queries and all focused age figures use 0–19, 20–39, 40–59 and 60+.
The age time series separates sex by line type and population source by colour.
The age snapshot compares both sources in separate sex panels; its table includes sex.
Legacy report age bands and the published ten-year reference file remain unchanged.

The regional IMD chart uses national quintiles within seven NHS-region panels,
with a common percentage axis. Each bar sums both sources over the same eligible
LSOAs at the selected snapshot.
A coverage table separates invalid IMD and missing source records. Unavailable
quintiles remain NA, and zero ONS denominators have no percentage.
The base R fixture checks aggregation before percentage calculation, total
reconciliation, missing pairs, non-English exclusions, zero denominators and
invalid/duplicate keys. Python age fixtures check all integer boundaries for both
the focused broad bands and the legacy ten-year bands.

## ICB decile map

The focused report restores an ICB map using the official ONS April 2026 BSC
(200 m coast-clipped) boundary service. Install the additional `sf` dependency.
The downloaded layer is validated against all 36 ICB codes in the report lookup
and cached in `data/ICB_April2026_BSC.geojson`; an invalid cache is refreshed.
No live registration or ONS population values are downloaded by the map loader.

Colours show deciles of the signed percentage difference relative to ONS from
the residence-based ICB snapshot. Type-7 quantile thresholds are calculated from
finite ICB percentages. Values on thresholds fall in the lower group; identical
values always share a group. Ties may leave empty deciles, which the key table
identifies. Missing/undefined values are grey. The existing ICB table includes
each area's map decile, alongside the actual percentages and counts.

Run `Rscript tests/test_icb_map_deciles.R` to check the classification, ties,
negative differences, nonfinite values, all-equal data, permutation invariance
and invalid input. This fixture requires only base R, not sf or the warehouse.

The focused report no longer loads historical LSOA registration/ONS extracts,
resolves a legacy 2011-LSOA registration table, or sources the IMD trend helper.
The national, age/sex and GP-FTE histories continue to request data from 2013.
The standalone `14_Summarise_IMD_Trends.R` helper and its R fixtures remain for
older callers; they are not used by the focused report.

## Difference maps and chart CSVs

Two additional ICB maps show the signed differences in the actual rate units:
registered patients per GP FTE minus ONS residents per GP FTE, and the ONS-based
annual payment average minus the registered-patient-based average. The payment
total stays fixed. Each map has ten quantile colours calculated from its own
ICB differences, using the existing tie and missing-value policy. The CSVs retain
both rates, populations, FTE/payments, difference definitions and decile ranges.
These maps show differences rather than separate source panels or percentage
transformations. The FTE percentage difference would duplicate the population
percentage map, so the new FTE map uses people per FTE.

Every call to `label_chart()` writes its top-level ggplot data to
`outputs/chart_data/<chunk-id>.csv`. Set `params$chart_data_dir` to change the
folder. The same numeric data used by the chart are exported without display
rounding; dates are ISO text, factors are text, undefined/nonfinite values are
blank, and sf geometry is omitted. Source inputs, the report reference date and
payment snapshot date are metadata columns. Historical observation dates stay
in their original Period column; the reference date is not their observation
date. National fixed-payment chart rows now retain the full payment total and
both population counts as well as the plotted average.

At successful completion, `manifest.csv` lists all 27 chart files, sources and
row counts. Coverage must exactly match the report's chart IDs. Only obsolete
CSV files named in a previous generated manifest are removed; unrelated files
are retained. CSVs contain aggregate chart data, not individual patient records.
Actual warehouse data files are generated by rendering the report in the R and
warehouse environment; the repository does not contain fabricated population,
workforce or payment CSVs.

Run `Rscript tests/test_chart_csv_exports.R` and
`Rscript tests/test_icb_difference_maps.R` for numeric/CSV round trips,
missing values, manifest coverage, stale-file handling, signed differences,
retained denominators and geography validation. These fixtures require only base R.

## Payment components and chart styling

Potential-loss scenarios at national, regional and ICB level use Global Sum, MPIG
Correction Factor, Balance of PMS Expenditure, Out of Area in Hours Urgent
Care and GP Extended Hours Access from one latest payment snapshot. The five
headers were verified against the NHS England 2024/25 practice CSV. Matching
ignores case and whitespace; a missing category at the selected snapshot
fails with its name. Signed adjustments are retained. Published aggregate
payments and recorded PCN Participation are excluded from the calculation.

The model adds PCN Participation at £41.578 per baseline registered patient.
It is applied once before the selected total is used for the proportional
loss scenario. The fixed-total averages instead use the published Total NHS
Payments to General Practice Minus Deductions without any custom top-up.
Selected published payments and the modelled addition reconcile to England,
including amounts without a local assignment. The England component table
and funding CSVs expose the breakdown and rate separately.

The age time-series panels begin at zero. Age and sex percentage labels show
the signed raw difference in brackets. All four maps use the same discrete
blue-to-red palette, from lowest to highest differences, with missing values
grey. Deciles still rank differences and do not identify the zero point.

Run `Rscript tests/test_payment_components.R` for the selection, signed
adjustments, custom PCN rate, aggregation and both funding models.

## Separate fixed-total and potential-loss payment bases

The England, regional and ICB fixed-total average comparisons and their ICB
map use the full published field `Total NHS Payments to General Practice Minus
Deductions`. They have no custom PCN Participation top-up. This field is read
at the same payment snapshot as the narrowed loss components; missing data at
that snapshot must not fall back to a different payment year. Local full
payment totals plus unassigned amounts reconcile to England independently
of the narrowed payment model.

Potential losses retain the five selected components plus £41.578 per
baseline registered patient in modelled PCN Participation. The narrowed
component summary is displayed in the loss section. The new loss map uses
annual loss per ONS resident with ten blue-to-red deciles and includes total
loss, percentage loss, populations and components in its CSV. Zero-resident
rates remain undefined and grey. The fixed-total payment map retains the
ONS-average-minus-registered-average difference in pounds per person.

Funding chart CSVs include a `Payment_Basis` field distinguishing the two
models. There are 27 chart CSVs plus the manifest after a successful render.
The payment R fixture demonstrates a full published total of £999,000
versus a narrowed modelled total of £5,657.80, checks fixed-total averages
separately from loss calculations and rejects missing/invalid aggregate
payments at the selected snapshot. Portable integration checks ensure each
scenario and map receives the intended payment base.
