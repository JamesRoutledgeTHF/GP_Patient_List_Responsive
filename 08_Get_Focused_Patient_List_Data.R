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

national_registered <- DBI::dbGetQuery(
  con,
  glue::glue("
    SELECT
      Effective_Snapshot_Date AS Period,
      SUM(Size) AS Population
    FROM Demography.No_Of_Patients_Regd_At_GP_Practice_LSOA_2021_Level1
    WHERE Effective_Snapshot_Date >= '{start_sql}'
      AND Effective_Snapshot_Date <= '{end_sql}'
      AND LSOA_Code LIKE 'E01%'
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
      AND Area_Code LIKE 'E01%'
    GROUP BY Effective_Snapshot_Date
    ORDER BY Effective_Snapshot_Date
  ")
) %>%
  dplyr::mutate(
    Period = as.Date(Period),
    Source = "ONS population estimate"
  )

practice_registered_demographic_time_series <- DBI::dbGetQuery(
  con,
  glue::glue("
    SELECT
      Effective_Snapshot_Date AS Period,
      CASE
        WHEN UPPER(Sex) = 'FEMALE' THEN 'Female'
        WHEN UPPER(Sex) = 'MALE' THEN 'Male'
      END AS Sex,
      {age_case} AS Age_Band,
      SUM(Size) AS Registered
    FROM Demography.No_Of_Patients_Regd_At_GP_Practice_Single_Age1
    WHERE Effective_Snapshot_Date >= '{start_sql}'
      AND Effective_Snapshot_Date <= '{end_sql}'
      AND UPPER(Sex) IN ('FEMALE', 'MALE')
    GROUP BY
      Effective_Snapshot_Date,
      CASE
        WHEN UPPER(Sex) = 'FEMALE' THEN 'Female'
        WHEN UPPER(Sex) = 'MALE' THEN 'Male'
      END,
      {age_case}
    ORDER BY Effective_Snapshot_Date
  ")
) %>%
  dplyr::mutate(Period = as.Date(Period)) %>%
  dplyr::filter(!is.na(Sex), !is.na(Age_Band))

ons_demographic_time_series <- DBI::dbGetQuery(
  con,
  glue::glue("
    SELECT
      Effective_Snapshot_Date AS Period,
      CASE
        WHEN UPPER(Sex) = 'FEMALE' THEN 'Female'
        WHEN UPPER(Sex) = 'MALE' THEN 'Male'
      END AS Sex,
      {age_case} AS Age_Band,
      SUM(Size) AS ONS
    FROM Demography.ONS_Population_Estimates_For_LSOAs_By_Year_Of_Age1
    WHERE Effective_Snapshot_Date >= '{start_sql}'
      AND Effective_Snapshot_Date <= '{end_sql}'
      AND Area_Code LIKE 'E01%'
      AND UPPER(Sex) IN ('FEMALE', 'MALE')
    GROUP BY
      Effective_Snapshot_Date,
      CASE
        WHEN UPPER(Sex) = 'FEMALE' THEN 'Female'
        WHEN UPPER(Sex) = 'MALE' THEN 'Male'
      END,
      {age_case}
    ORDER BY Effective_Snapshot_Date
  ")
) %>%
  dplyr::mutate(Period = as.Date(Period)) %>%
  dplyr::filter(!is.na(Sex), !is.na(Age_Band))

lsoa_registered_july <- DBI::dbGetQuery(
  con,
  glue::glue("
    SELECT
      LSOA_Code,
      Effective_Snapshot_Date AS Period,
      SUM(Size) AS Registered
    FROM Demography.No_Of_Patients_Regd_At_GP_Practice_LSOA_2021_Level1
    WHERE Effective_Snapshot_Date = '{snapshot_sql}'
      AND LSOA_Code LIKE 'E01%'
    GROUP BY LSOA_Code, Effective_Snapshot_Date
  ")
) %>%
  dplyr::mutate(Period = as.Date(Period))

lsoa_ons_july <- DBI::dbGetQuery(
  con,
  glue::glue("
    SELECT
      Area_Code AS LSOA_Code,
      Effective_Snapshot_Date AS Period,
      SUM(Size) AS ONS
    FROM Demography.ONS_Population_Estimates_For_LSOAs_By_Year_Of_Age1
    WHERE Effective_Snapshot_Date = '{snapshot_sql}'
      AND Area_Code LIKE 'E01%'
    GROUP BY Area_Code, Effective_Snapshot_Date
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

practice_registered_snapshot <- DBI::dbGetQuery(
  con,
  glue::glue("
    SELECT
      GP_Practice_Code AS Practice_Code,
      SUM(Size) AS Registered
    FROM Demography.No_Of_Patients_Regd_At_GP_Practice_Single_Age1
    WHERE Effective_Snapshot_Date = '{snapshot_sql}'
      AND GP_Practice_Code IS NOT NULL
    GROUP BY GP_Practice_Code
  ")
) %>%
  dplyr::mutate(Practice_Code = as.character(Practice_Code))

workforce_table <- DBI::Id(
  schema = "NHS_Workforce",
  table = "Practice_Level_Census_Data1"
)
workforce_fields <- DBI::dbListFields(con, workforce_table)

find_field <- function(fields, exact, regex) {
  hit <- exact[exact %in% fields]
  if (length(hit) > 0) return(hit[[1]])

  hit <- fields[grepl(regex, fields, ignore.case = TRUE)]
  if (length(hit) > 0) return(hit[[1]])

  NA_character_
}

workforce_practice_field <- find_field(
  workforce_fields,
  exact = c(
    "Practice_Code", "GP_Practice_Code", "PRACTICE_CODE",
    "Practice code", "Organisation_Code", "Organisation code"
  ),
  regex = "practice.*code|organisation.*code|prac.*code"
)

workforce_date_field <- find_field(
  workforce_fields,
  exact = c(
    "Effective_Snapshot_Date", "Snapshot_Date", "Snapshot date",
    "Period", "Date"
  ),
  regex = "snapshot.*date|effective.*date|^period$|^date$"
)

workforce_fte_field <- find_field(
  workforce_fields,
  exact = c(
    "TOTAL_GP_EXTG_FTE", "Total_GP_EXTG_FTE", "Qualified_GP_FTE",
    "GP_FTE"
  ),
  regex = "total.*gp.*fte|qualified.*gp.*fte|(^|_)gp.*fte"
)

missing_workforce_fields <- c(
  Practice_Code = workforce_practice_field,
  Period = workforce_date_field,
  GP_FTE = workforce_fte_field
)
missing_workforce_fields <- names(missing_workforce_fields)[
  is.na(missing_workforce_fields)
]

if (length(missing_workforce_fields) > 0) {
  stop(
    "Could not identify the following workforce fields in ",
    "NHS_Workforce.Practice_Level_Census_Data1: ",
    paste(missing_workforce_fields, collapse = ", "),
    ". Available fields are: ",
    paste(workforce_fields, collapse = ", ")
  )
}

q_practice <- as.character(DBI::dbQuoteIdentifier(con, workforce_practice_field))
q_period <- as.character(DBI::dbQuoteIdentifier(con, workforce_date_field))
q_fte <- as.character(DBI::dbQuoteIdentifier(con, workforce_fte_field))
q_workforce_table <- as.character(DBI::dbQuoteIdentifier(con, workforce_table))

qualified_gp_workforce <- DBI::dbGetQuery(
  con,
  glue::glue("
    SELECT
      {q_practice} AS Practice_Code,
      {q_period} AS Period,
      SUM(TRY_CAST({q_fte} AS FLOAT)) AS GP_FTE
    FROM {q_workforce_table}
    WHERE {q_period} >= '{start_sql}'
      AND {q_period} <= '{end_sql}'
      AND {q_practice} IS NOT NULL
    GROUP BY {q_practice}, {q_period}
    ORDER BY {q_period}, {q_practice}
  ")
) %>%
  dplyr::mutate(
    Practice_Code = as.character(Practice_Code),
    Period = as.Date(Period),
    GP_FTE = as.numeric(GP_FTE)
  )
