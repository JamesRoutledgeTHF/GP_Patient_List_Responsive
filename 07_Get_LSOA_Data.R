query <- "
SELECT *
FROM Demography.No_Of_Patients_Regd_At_GP_Practice_LSOA_2021_Level1
WHERE Effective_Snapshot_Date >= '2025-10-01'
"

LSOA_Patient_Reg <- DBI::dbGetQuery(con, query)


query2 <- "
SELECT *
FROM Demography.Index_Of_Multiple_Deprivation_By_LSOA1
WHERE Effective_Snapshot_Date = '2025-12-31'
"

LSOA_IMD <- DBI::dbGetQuery(con, query2)

query3 <- "
SELECT
    Area_Code,
    Effective_Snapshot_Date,
    SUM(Size) AS Total_Size
FROM Demography.ONS_Population_Estimates_For_LSOAs_By_Year_Of_Age1
WHERE Effective_Snapshot_Date >= '2024-07-01'
GROUP BY
    Area_Code,
    Effective_Snapshot_Date
ORDER BY
    Area_Code,
    Effective_Snapshot_Date
"

LSOA_ONS <- DBI::dbGetQuery(con, query3)


query4 <- "
SELECT
    LSOA_Code,
    Effective_Snapshot_Date,
    SUM(Size) AS Total_Size
FROM Demography.No_Of_Patients_Regd_At_GP_Practice_LSOA_2021_Level1
WHERE Effective_Snapshot_Date = '2024-07-01'
GROUP BY
    LSOA_Code,
    Effective_Snapshot_Date
ORDER BY
    LSOA_Code
"

LSOA_Patient_Reg_2024 <- DBI::dbGetQuery(con, query4)


query5 <- "
SELECT
    Area_Code,
    Effective_Snapshot_Date,
    Sex,
    SUM(Size) AS Total_Size
FROM Demography.ONS_Population_Estimates_For_LSOAs_By_Year_Of_Age1
WHERE Effective_Snapshot_Date >= '2024-07-01'
GROUP BY
    Area_Code,
    Effective_Snapshot_Date,
    Sex
ORDER BY
    Area_Code,
    Effective_Snapshot_Date,
    Sex
"

LSOA_ONS_SEX <- DBI::dbGetQuery(con, query5)


query7 <- "
SELECT
    LSOA_Code,
    Effective_Snapshot_Date,
    Sex,
    SUM(Size) AS Total_Size
FROM Demography.No_Of_Patients_Regd_At_GP_Practice_LSOA_2021_Level1
WHERE Effective_Snapshot_Date = '2024-07-01'
GROUP BY
    LSOA_Code,
    Effective_Snapshot_Date,
    Sex
ORDER BY
    LSOA_Code,
    Effective_Snapshot_Date,
    Sex
"

LSOA_Patient_Reg_2024_Sex <- DBI::dbGetQuery(con, query7)