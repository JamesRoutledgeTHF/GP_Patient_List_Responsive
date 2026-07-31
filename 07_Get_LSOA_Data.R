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


query_age <- "
SELECT
    Effective_Snapshot_Date,
    CASE
        WHEN Age = '95+' THEN '81+'
        WHEN CAST(Age AS INT) BETWEEN 0 AND 10 THEN '0-10'
        WHEN CAST(Age AS INT) BETWEEN 11 AND 20 THEN '11-20'
        WHEN CAST(Age AS INT) BETWEEN 21 AND 30 THEN '21-30'
        WHEN CAST(Age AS INT) BETWEEN 31 AND 40 THEN '31-40'
        WHEN CAST(Age AS INT) BETWEEN 41 AND 50 THEN '41-50'
        WHEN CAST(Age AS INT) BETWEEN 51 AND 60 THEN '51-60'
        WHEN CAST(Age AS INT) BETWEEN 61 AND 70 THEN '61-70'
        WHEN CAST(Age AS INT) BETWEEN 71 AND 80 THEN '71-80'
        ELSE '81+'
    END AS Age_Band,
    SUM(Size) AS Total_Size
FROM Demography.No_Of_Patients_Regd_At_GP_Practice_Single_Age1
WHERE Effective_Snapshot_Date = '2024-07-01'
  AND Sex IN ('FEMALE', 'MALE')
GROUP BY
    Effective_Snapshot_Date,
    CASE
        WHEN Age = '95+' THEN '81+'
        WHEN CAST(Age AS INT) BETWEEN 0 AND 10 THEN '0-10'
        WHEN CAST(Age AS INT) BETWEEN 11 AND 20 THEN '11-20'
        WHEN CAST(Age AS INT) BETWEEN 21 AND 30 THEN '21-30'
        WHEN CAST(Age AS INT) BETWEEN 31 AND 40 THEN '31-40'
        WHEN CAST(Age AS INT) BETWEEN 41 AND 50 THEN '41-50'
        WHEN CAST(Age AS INT) BETWEEN 51 AND 60 THEN '51-60'
        WHEN CAST(Age AS INT) BETWEEN 61 AND 70 THEN '61-70'
        WHEN CAST(Age AS INT) BETWEEN 71 AND 80 THEN '71-80'
        ELSE '81+'
    END
"

LSOA_Patient_Reg_age_2024 <- DBI::dbGetQuery(con, query_age)


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


query8 <- "
SELECT
    Area_Code,
    Effective_Snapshot_Date,
    Age,
    SUM(Size) AS Total_Size
FROM Demography.ONS_Population_Estimates_For_LSOAs_By_Year_Of_Age1
WHERE Effective_Snapshot_Date = '2024-07-01'
GROUP BY
    Area_Code,
    Effective_Snapshot_Date,
    Age
ORDER BY
    Area_Code,
    Effective_Snapshot_Date,
    Age
"

LSOA_ONS_Age <- DBI::dbGetQuery(con, query8)


query_ons_age <- "
SELECT
    Effective_Snapshot_Date,
    CASE
        WHEN Age = '95+' THEN '81+'
        WHEN CAST(Age AS INT) BETWEEN 0 AND 10 THEN '0-10'
        WHEN CAST(Age AS INT) BETWEEN 11 AND 20 THEN '11-20'
        WHEN CAST(Age AS INT) BETWEEN 21 AND 30 THEN '21-30'
        WHEN CAST(Age AS INT) BETWEEN 31 AND 40 THEN '31-40'
        WHEN CAST(Age AS INT) BETWEEN 41 AND 50 THEN '41-50'
        WHEN CAST(Age AS INT) BETWEEN 51 AND 60 THEN '51-60'
        WHEN CAST(Age AS INT) BETWEEN 61 AND 70 THEN '61-70'
        WHEN CAST(Age AS INT) BETWEEN 71 AND 80 THEN '71-80'
        ELSE '81+'
    END AS Age_Band,
    SUM(Size) AS Total_Size
FROM Demography.ONS_Population_Estimates_For_LSOAs_By_Year_Of_Age1
WHERE Effective_Snapshot_Date = '2024-07-01'
  AND Area_Code NOT LIKE 'W0%'
  AND Area_Code <> 'OTHER'
GROUP BY
    Effective_Snapshot_Date,
    CASE
        WHEN Age = '95+' THEN '81+'
        WHEN CAST(Age AS INT) BETWEEN 0 AND 10 THEN '0-10'
        WHEN CAST(Age AS INT) BETWEEN 11 AND 20 THEN '11-20'
        WHEN CAST(Age AS INT) BETWEEN 21 AND 30 THEN '21-30'
        WHEN CAST(Age AS INT) BETWEEN 31 AND 40 THEN '31-40'
        WHEN CAST(Age AS INT) BETWEEN 41 AND 50 THEN '41-50'
        WHEN CAST(Age AS INT) BETWEEN 51 AND 60 THEN '51-60'
        WHEN CAST(Age AS INT) BETWEEN 61 AND 70 THEN '61-70'
        WHEN CAST(Age AS INT) BETWEEN 71 AND 80 THEN '71-80'
        ELSE '81+'
    END

"

LSOA_ONS_Age_group <- DBI::dbGetQuery(con, query_ons_age)


query_ons_age_sex <- "
SELECT
    Effective_Snapshot_Date,
    Sex,
    CASE
        WHEN Age = '95+' THEN '81+'
        WHEN CAST(Age AS INT) BETWEEN 0 AND 10 THEN '0-10'
        WHEN CAST(Age AS INT) BETWEEN 11 AND 20 THEN '11-20'
        WHEN CAST(Age AS INT) BETWEEN 21 AND 30 THEN '21-30'
        WHEN CAST(Age AS INT) BETWEEN 31 AND 40 THEN '31-40'
        WHEN CAST(Age AS INT) BETWEEN 41 AND 50 THEN '41-50'
        WHEN CAST(Age AS INT) BETWEEN 51 AND 60 THEN '51-60'
        WHEN CAST(Age AS INT) BETWEEN 61 AND 70 THEN '61-70'
        WHEN CAST(Age AS INT) BETWEEN 71 AND 80 THEN '71-80'
        ELSE '81+'
    END AS Age_Band,
    SUM(Size) AS Total_Size
FROM Demography.ONS_Population_Estimates_For_LSOAs_By_Year_Of_Age1
WHERE Effective_Snapshot_Date = '2024-07-01'
  AND Area_Code NOT LIKE 'W0%'
  AND Area_Code <> 'OTHER'
  AND Sex IN ('MALE', 'FEMALE')
GROUP BY
    Effective_Snapshot_Date,
    Sex,
    CASE
        WHEN Age = '95+' THEN '81+'
        WHEN CAST(Age AS INT) BETWEEN 0 AND 10 THEN '0-10'
        WHEN CAST(Age AS INT) BETWEEN 11 AND 20 THEN '11-20'
        WHEN CAST(Age AS INT) BETWEEN 21 AND 30 THEN '21-30'
        WHEN CAST(Age AS INT) BETWEEN 31 AND 40 THEN '31-40'
        WHEN CAST(Age AS INT) BETWEEN 41 AND 50 THEN '41-50'
        WHEN CAST(Age AS INT) BETWEEN 51 AND 60 THEN '51-60'
        WHEN CAST(Age AS INT) BETWEEN 61 AND 70 THEN '61-70'
        WHEN CAST(Age AS INT) BETWEEN 71 AND 80 THEN '71-80'
        ELSE '81+'
    END
"

LSOA_ONS_Age_Sex_group <- DBI::dbGetQuery(con, query_ons_age_sex)


query_age_sex <- "
SELECT
    Effective_Snapshot_Date,
    CASE
        WHEN Sex = 'FEMALE' THEN 'Female'
        WHEN Sex = 'MALE' THEN 'Male'
    END AS Sex,
    CASE
        WHEN Age = '95+' THEN '81+'
        WHEN CAST(Age AS INT) BETWEEN 0 AND 10 THEN '0-10'
        WHEN CAST(Age AS INT) BETWEEN 11 AND 20 THEN '11-20'
        WHEN CAST(Age AS INT) BETWEEN 21 AND 30 THEN '21-30'
        WHEN CAST(Age AS INT) BETWEEN 31 AND 40 THEN '31-40'
        WHEN CAST(Age AS INT) BETWEEN 41 AND 50 THEN '41-50'
        WHEN CAST(Age AS INT) BETWEEN 51 AND 60 THEN '51-60'
        WHEN CAST(Age AS INT) BETWEEN 61 AND 70 THEN '61-70'
        WHEN CAST(Age AS INT) BETWEEN 71 AND 80 THEN '71-80'
        ELSE '81+'
    END AS Age_Band,
    SUM(Size) AS Total_Size
FROM Demography.No_Of_Patients_Regd_At_GP_Practice_Single_Age1
WHERE Effective_Snapshot_Date = '2024-07-01'
  AND Sex IN ('FEMALE', 'MALE')
GROUP BY
    Effective_Snapshot_Date,
    CASE
        WHEN Sex = 'FEMALE' THEN 'Female'
        WHEN Sex = 'MALE' THEN 'Male'
    END,
    CASE
        WHEN Age = '95+' THEN '81+'
        WHEN CAST(Age AS INT) BETWEEN 0 AND 10 THEN '0-10'
        WHEN CAST(Age AS INT) BETWEEN 11 AND 20 THEN '11-20'
        WHEN CAST(Age AS INT) BETWEEN 21 AND 30 THEN '21-30'
        WHEN CAST(Age AS INT) BETWEEN 31 AND 40 THEN '31-40'
        WHEN CAST(Age AS INT) BETWEEN 41 AND 50 THEN '41-50'
        WHEN CAST(Age AS INT) BETWEEN 51 AND 60 THEN '51-60'
        WHEN CAST(Age AS INT) BETWEEN 61 AND 70 THEN '61-70'
        WHEN CAST(Age AS INT) BETWEEN 71 AND 80 THEN '71-80'
        ELSE '81+'
    END
"

LSOA_Patient_Reg_age_sex_2024 <- DBI::dbGetQuery(con, query_age_sex)
