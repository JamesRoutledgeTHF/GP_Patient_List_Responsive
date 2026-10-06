# April 2026 ICB geography

The reports keep their original patient, ONS population, workforce and payment
snapshots. Script 09 changes the geography to the official ONS April 2026
LSOA21/SICBL26/ICB26/NHSER26 lookup. The July 2024 population snapshot remains
July 2024. April 2026 has 36 ICBs. NHS region boundaries did not change.

Sources:

- [ONS April 2026 LSOA lookup](https://www.data.gov.uk/dataset/1d16e489-1dc8-443e-9e1c-15de4f961c6d/lsoa-2021-to-sicbl-to-icb-to-nhser-to-lad-april-2026-lookup-in-en)
- [ONS ArcGIS lookup service](https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/LSOA21_SICBL26_ICB26_NHSER26_LAD26/FeatureServer/0)
- [NHS ODS April 2026 change summary](https://digital.nhs.uk/services/organisation-data-service/upcoming-code-changes/icb-mergers-2026-change-summary)

## Practices

Script 10 retains the practice codes and Sub ICB codes from payments2425.csv.
All surviving Sub ICB codes have a unique relationship to a 2026 ICB in the
ONS lookup. The abolished Frimley Sub ICB code D4U1Y is split between Thames
Valley, Surrey and Sussex, and Hampshire and Isle of Wight; it must not be
assigned wholesale to one successor.

frimley_practice_icb26.csv supplies an explicit assignment for all 75 Frimley
practices present in payments2425.csv:

- 66 use their commissioning ICB in the [NHS May 2026 practice mapping](https://digital.nhs.uk/data-and-information/publications/statistical/patients-registered-at-a-gp-practice/may-2026),
  downloaded from [the publication's mapping ZIP](https://files.digital.nhs.uk/F0/417B36/gp-reg-pat-prac-map_V2.zip).
- Nine historical practices absent from that file use the postcode recorded
  in payments2425.csv and its ICB26CD in the [ONS May 2026 Postcode Directory](https://www.arcgis.com/home/item.html?id=d1317f804688417287de8f8224ecc942).
  Their LSOA21CD is retained for checking against the LSOA lookup.

The postcode assignments are geographic estimates for historical practices,
not confirmed commissioning relationships for organisations that no longer
exist. They preserve the original records rather than dropping their counts
or inventing practice-successor transfers. Mapping_Basis identifies these
rows. Review these nine assignments if a commissioning-specific historical
crosswalk becomes available.

All 6,375 practices in payments2425.csv are assigned once, using official ICB
codes as join keys. Missing, conflicting or invalid mappings stop rendering.
New practice records require additions to the source practice geography; they
must not be silently assigned using an obsolete ICB name.

## Overall GP practice versus GP LSOA table

Both reports compare the two GP registration sources for the same July 2024
snapshot. The LSOA total is summed before any ONS join or residence-geography
filter, including Welsh and other/unassigned records. Difference is the
practice total minus the GP LSOA total, and percentage difference divides by
the practice total. It is not a GP-versus-ONS comparison and does not itself
identify ghost patients.

## Published mid-2024 ONS age reference

`ons_mid2024_age_band_reference.csv` is a fixed benchmark extracted from ONS
`mye24tablesew.xlsx`, edition **Mid-2024: 2023 local authority boundaries**, released
30 July 2025. Source: [ONS edition page](https://www.ons.gov.uk/peoplepopulationandcommunity/populationandmigration/populationestimates/datasets/estimatesofthepopulationforenglandandwales/mid20242023localauthorityboundaries)
and [workbook](https://www.ons.gov.uk/file?uri=%2Fpeoplepopulationandcommunity%2Fpopulationandmigration%2Fpopulationestimates%2Fdatasets%2Festimatesofthepopulationforenglandandwales%2Fmid20242023localauthorityboundaries%2Fmye24tablesew.xlsx).

The `MYE2 - Persons` worksheet has single-year columns, plus a final 90+
column. For each of country codes E92000001 (England), W92000004 (Wales), and
K04000001 (England and Wales), sum 0 through 9, 10 through 19, and so on,
retaining the published 90+ cell. The 0–9 calculation uses columns E:N, excludes
age ten in column O, and does not add male/female rows to Persons. All bands
sum to the published all-age country totals; England plus Wales reconciles
with England and Wales in every band.

This benchmark retains its publication vintage and does not replace warehouse
estimates. Its reference date is 30 June 2024. A warehouse Effective_Snapshot_Date
of July 2024 does not establish which reference year or revision was loaded.
The focused report shows discrepancies explicitly. Its England-only denominator
remains appropriate for the existing scope; Welsh totals are shown for comparison.

Both reports now use identical ten-year age boundaries. The older report's
previous 0–10/11–20 SQL groups and relabelling of registered 0–9 as 0–10 have
been corrected, including separate 80–89 and 90+ bands.
