# Load database results for 05_Patient_List_Focused.Rmd.
# Expects `con`, `start_date`, `end_date`, and `snapshot_date` to exist.

required_objects <- c("con", "start_date", "end_date", "snapshot_date")
missing_objects <- required_objects[
  !vapply(required_objects, exists, logical(1), inherits = TRUE)
]

if (length(missing_objects) > 0) {
  stop(
    "08_Get_Focused_Patient_List_Data.R requires: ",
    paste(missing_objects, collapse = ", ")
  )
}

date_sql <- function(x) format(as.Date(x), "%Y-%m-%d")
start_sql <- date_sql(start_date)
end_sql <- date_sql(end_date)
snapshot_sql <- date_sql(snapshot_date)

national_registered <- DBI::dbGetQuery(
  con,
  glue::glue("
    SELECT
      Effective_Snapshot_Date AS Period,
      SUM(Size) AS Population
    FROM Demography.No_Of_Patients_Regd_At_GP_Practice_Single_Age1
    WHERE Effective_Snapshot_Date >= '{start_sql}'
      AND Effective_Snapshot_Date <= '{end_sql}'
    GROUP BY Effective_Snapshot_Date
    ORDER BY Effective_Snapshot_Date
  ")
) %>%
  dplyr::mutate(
    Period = as.Date(Period),
    Source = "Registered patients"
  )

national_ons <- DBI::dbGetQuery(
  con,
  glue::glue("
    SELECT
      Effective_Snapshot_Date AS Period,
      SUM(Size) AS Population
    FROM Demography.ONS_Population_Estimates_For_LSOAs_By_Year_Of_Age1
    WHERE Effective_Snapshot_Date >= '{start_sql}'
      AND Effective_Snapshot_Date <= '{end_sql}'
      AND Area_Code NOT LIKE 'W0%'
      AND Area_Code <> 'OTHER'
    GROUP BY Effective_Snapshot_Date
    ORDER BY Effective_Snapshot_Date
  ")
) %>%
  dplyr::mutate(
    Period = as.Date(Period),
    Source = "ONS population estimate"
  )

lsoa_registered_snapshot <- DBI::dbGetQuery(
  con,
  glue::glue("
    SELECT
      LSOA_Code,
      SUM(Size) AS Registered
    FROM Demography.No_Of_Patients_Regd_At_GP_Practice_LSOA_2021_Level1
    WHERE Effective_Snapshot_Date = '{snapshot_sql}'
      AND LSOA_Code LIKE 'E01%'
    GROUP BY LSOA_Code
  ")
)

lsoa_ons_snapshot <- DBI::dbGetQuery(
  con,
  glue::glue("
    SELECT
      Area_Code AS LSOA_Code,
      SUM(Size) AS ONS
    FROM Demography.ONS_Population_Estimates_For_LSOAs_By_Year_Of_Age1
    WHERE Effective_Snapshot_Date = '{snapshot_sql}'
      AND Area_Code LIKE 'E01%'
    GROUP BY Area_Code
  ")
)

practice_registered_snapshot <- DBI::dbGetQuery(
  con,
  glue::glue("
    SELECT
      GP_Practice_Code AS Practice_Code,
      SUM(Size) AS Registered
    FROM Demography.No_Of_Patients_Regd_At_GP_Practice_Single_Age1
    WHERE Effective_Snapshot_Date = '{snapshot_sql}'
    GROUP BY GP_Practice_Code
  ")
)

age_case <- "
  CASE
    WHEN Age = '95+' THEN '90+'
    WHEN TRY_CAST(Age AS INT) BETWEEN 0 AND 9 THEN '0-9'
    WHEN TRY_CAST(Age AS INT) BETWEEN 10 AND 19 THEN '10-19'
    WHEN TRY_CAST(Age AS INT) BETWEEN 20 AND 29 THEN '20-29'
    WHEN TRY_CAST(Age AS INT) BETWEEN 30 AND 39 THEN '30-39'
    WHEN TRY_CAST(Age AS INT) BETWEEN 40 AND 49 THEN '40-49'
    WHEN TRY_CAST(Age AS INT) BETWEEN 50 AND 59 THEN '50-59'
    WHEN TRY_CAST(Age AS INT) BETWEEN 60 AND 69 THEN '60-69'
    WHEN TRY_CAST(Age AS INT) BETWEEN 70 AND 79 THEN '70-79'
    WHEN TRY_CAST(Age AS INT) BETWEEN 80 AND 89 THEN '80-89'
    WHEN TRY_CAST(Age AS INT) >= 90 THEN '90+'
    ELSE NULL
  END
"

practice_registered_demographic_snapshot <- DBI::dbGetQuery(
  con,
  glue::glue("
    SELECT
      CASE
        WHEN UPPER(Sex) = 'FEMALE' THEN 'Female'
        WHEN UPPER(Sex) = 'MALE' THEN 'Male'
      END AS Sex,
      {age_case} AS Age_Band,
      SUM(Size) AS Registered
    FROM Demography.No_Of_Patients_Regd_At_GP_Practice_Single_Age1
    WHERE Effective_Snapshot_Date = '{snapshot_sql}'
      AND UPPER(Sex) IN ('FEMALE', 'MALE')
    GROUP BY
      CASE
        WHEN UPPER(Sex) = 'FEMALE' THEN 'Female'
        WHEN UPPER(Sex) = 'MALE' THEN 'Male'
      END,
      {age_case}
  ")
) %>%
  dplyr::filter(!is.na(Age_Band), !is.na(Sex))

ons_demographic_snapshot <- DBI::dbGetQuery(
  con,
  glue::glue("
    SELECT
      CASE
        WHEN UPPER(Sex) = 'FEMALE' THEN 'Female'
        WHEN UPPER(Sex) = 'MALE' THEN 'Male'
      END AS Sex,
      {age_case} AS Age_Band,
      SUM(Size) AS ONS
    FROM Demography.ONS_Population_Estimates_For_LSOAs_By_Year_Of_Age1
    WHERE Effective_Snapshot_Date = '{snapshot_sql}'
      AND Area_Code LIKE 'E01%'
      AND UPPER(Sex) IN ('FEMALE', 'MALE')
    GROUP BY
      CASE
        WHEN UPPER(Sex) = 'FEMALE' THEN 'Female'
        WHEN UPPER(Sex) = 'MALE' THEN 'Male'
      END,
      {age_case}
  ")
) %>%
  dplyr::filter(!is.na(Age_Band), !is.na(Sex))

qualified_gp_workforce <- DBI::dbGetQuery(
  con,
  glue::glue("
    SELECT
      Practice_Code,
      Effective_Snapshot_Date AS Period,
      SUM(TRY_CAST(Measure_Value AS FLOAT)) AS GP_FTE
    FROM NHS_Workforce.Practice_Level_Census_Data1
    WHERE Measure = 'TOTAL_GP_EXTG_FTE'
      AND Effective_Snapshot_Date >= '{start_sql}'
      AND Effective_Snapshot_Date <= '{end_sql}'
    GROUP BY Practice_Code, Effective_Snapshot_Date
    ORDER BY Effective_Snapshot_Date, Practice_Code
  ")
) %>%
  dplyr::mutate(Period = as.Date(Period))

imd_lookup <- DBI::dbGetQuery(
  con,
  "
    SELECT
      LSOA_Code,
      MAX(IMD_Decile) AS IMD_Decile
    FROM Demography.Index_Of_Multiple_Deprivation_By_LSOA1
    WHERE Effective_Snapshot_Date = (
      SELECT MAX(Effective_Snapshot_Date)
      FROM Demography.Index_Of_Multiple_Deprivation_By_LSOA1
    )
      AND LSOA_Code LIKE 'E01%'
    GROUP BY LSOA_Code
  "
)
