#function to get GP practice level data 
library(fingertipsR)
install.packages(c("curl", "httr", "miniUI"))
install.packages("fingertipsR", repos = "https://dev.ropensci.org")

get_gp_stats <- function(
    con,
    period = c("monthly", "yearly", "financial"),
    level = c("practice", "overall"),
    output_type = c("counts", "percentages"),
    start_date = NULL,
    end_date = NULL
) {
  
  period <- match.arg(period)
  level <- match.arg(level)
  output_type <- match.arg(output_type)
  
  date_group <- switch(
    period,
    monthly = "[Effective_Snapshot_Date]",
    yearly = "YEAR([Effective_Snapshot_Date])",
    financial = "
      CASE
        WHEN MONTH([Effective_Snapshot_Date]) >= 4 THEN
          CONCAT(YEAR([Effective_Snapshot_Date]), '/', RIGHT(CAST(YEAR([Effective_Snapshot_Date]) + 1 AS VARCHAR(4)), 2))
        ELSE
          CONCAT(YEAR([Effective_Snapshot_Date]) - 1, '/', RIGHT(CAST(YEAR([Effective_Snapshot_Date]) AS VARCHAR(4)), 2))
      END
    "
  )
  
  date_filter <- ""
  if (!is.null(start_date)) {
    date_filter <- paste0(date_filter,
                          sprintf(" AND [Effective_Snapshot_Date] >= '%s'", start_date))
  }
  if (!is.null(end_date)) {
    date_filter <- paste0(date_filter,
                          sprintf(" AND [Effective_Snapshot_Date] <= '%s'", end_date))
  }
  
  # =========================
  # PRACTICE LEVEL (unchanged structure but 10-year bands)
  # =========================
  if (level == "practice") {
    
    query <- sprintf("
    WITH base AS (
      SELECT
        [GP_Practice_Code],
        %s AS Period,
        [Age],
        [SEX],
        [Size]
      FROM [Demography].[No_Of_Patients_Regd_At_GP_Practice_Single_Age1]
      WHERE 1 = 1 %s
    ),

    aggregated AS (
      SELECT
        [GP_Practice_Code],
        Period,
        SUM(Size) AS Total_Size,

        SUM(CASE WHEN SEX = 'Male' THEN Size ELSE 0 END) AS Male_Count,
        SUM(CASE WHEN SEX = 'Female' THEN Size ELSE 0 END) AS Female_Count,

        SUM(CASE WHEN CAST(CASE WHEN Age='95+' THEN 95 ELSE Age END AS INT) BETWEEN 0 AND 9 THEN Size ELSE 0 END) AS Age_0_9,
        SUM(CASE WHEN CAST(CASE WHEN Age='95+' THEN 95 ELSE Age END AS INT) BETWEEN 10 AND 19 THEN Size ELSE 0 END) AS Age_10_19,
        SUM(CASE WHEN CAST(CASE WHEN Age='95+' THEN 95 ELSE Age END AS INT) BETWEEN 20 AND 29 THEN Size ELSE 0 END) AS Age_20_29,
        SUM(CASE WHEN CAST(CASE WHEN Age='95+' THEN 95 ELSE Age END AS INT) BETWEEN 30 AND 39 THEN Size ELSE 0 END) AS Age_30_39,
        SUM(CASE WHEN CAST(CASE WHEN Age='95+' THEN 95 ELSE Age END AS INT) BETWEEN 40 AND 49 THEN Size ELSE 0 END) AS Age_40_49,
        SUM(CASE WHEN CAST(CASE WHEN Age='95+' THEN 95 ELSE Age END AS INT) BETWEEN 50 AND 59 THEN Size ELSE 0 END) AS Age_50_59,
        SUM(CASE WHEN CAST(CASE WHEN Age='95+' THEN 95 ELSE Age END AS INT) BETWEEN 60 AND 69 THEN Size ELSE 0 END) AS Age_60_69,
        SUM(CASE WHEN CAST(CASE WHEN Age='95+' THEN 95 ELSE Age END AS INT) BETWEEN 70 AND 79 THEN Size ELSE 0 END) AS Age_70_79,
        SUM(CASE WHEN CAST(CASE WHEN Age='95+' THEN 95 ELSE Age END AS INT) BETWEEN 80 AND 89 THEN Size ELSE 0 END) AS Age_80_89,
        SUM(CASE WHEN CAST(CASE WHEN Age='95+' THEN 95 ELSE Age END AS INT) >= 90 THEN Size ELSE 0 END) AS Age_90_plus

      FROM base
      GROUP BY [GP_Practice_Code], Period
    )

    SELECT * FROM aggregated
    ORDER BY [GP_Practice_Code], Period
    ", date_group, date_filter)
    
  } else {
    
    # =========================
    # OVERALL LEVEL
    # =========================
    
    if (output_type == "counts") {
      
      query <- sprintf("
      WITH base AS (
        SELECT
          %s AS Period,
          [Age],
          [SEX],
          [Size]
        FROM [Demography].[No_Of_Patients_Regd_At_GP_Practice_Single_Age1]
        WHERE 1 = 1 %s
      ),

      aggregated AS (
        SELECT
          Period,
          SUM(Size) AS Total_Size,

          SUM(CASE WHEN SEX = 'Male' THEN Size ELSE 0 END) AS Male_Count,
          SUM(CASE WHEN SEX = 'Female' THEN Size ELSE 0 END) AS Female_Count,

          SUM(CASE WHEN CAST(CASE WHEN Age='95+' THEN 95 ELSE Age END AS INT) BETWEEN 0 AND 9 THEN Size ELSE 0 END) AS Age_0_9,
          SUM(CASE WHEN CAST(CASE WHEN Age='95+' THEN 95 ELSE Age END AS INT) BETWEEN 10 AND 19 THEN Size ELSE 0 END) AS Age_10_19,
          SUM(CASE WHEN CAST(CASE WHEN Age='95+' THEN 95 ELSE Age END AS INT) BETWEEN 20 AND 29 THEN Size ELSE 0 END) AS Age_20_29,
          SUM(CASE WHEN CAST(CASE WHEN Age='95+' THEN 95 ELSE Age END AS INT) BETWEEN 30 AND 39 THEN Size ELSE 0 END) AS Age_30_39,
          SUM(CASE WHEN CAST(CASE WHEN Age='95+' THEN 95 ELSE Age END AS INT) BETWEEN 40 AND 49 THEN Size ELSE 0 END) AS Age_40_49,
          SUM(CASE WHEN CAST(CASE WHEN Age='95+' THEN 95 ELSE Age END AS INT) BETWEEN 50 AND 59 THEN Size ELSE 0 END) AS Age_50_59,
          SUM(CASE WHEN CAST(CASE WHEN Age='95+' THEN 95 ELSE Age END AS INT) BETWEEN 60 AND 69 THEN Size ELSE 0 END) AS Age_60_69,
          SUM(CASE WHEN CAST(CASE WHEN Age='95+' THEN 95 ELSE Age END AS INT) BETWEEN 70 AND 79 THEN Size ELSE 0 END) AS Age_70_79,
          SUM(CASE WHEN CAST(CASE WHEN Age='95+' THEN 95 ELSE Age END AS INT) BETWEEN 80 AND 89 THEN Size ELSE 0 END) AS Age_80_89,
          SUM(CASE WHEN CAST(CASE WHEN Age='95+' THEN 95 ELSE Age END AS INT) >= 90 THEN Size ELSE 0 END) AS Age_90_plus

        FROM base
        GROUP BY Period
      )

      SELECT * FROM aggregated
      ORDER BY Period
      ", date_group, date_filter)
      
    } else {
      
      query <- sprintf("
      WITH base AS (
        SELECT
          %s AS Period,
          [Age],
          [SEX],
          [Size]
        FROM [Demography].[No_Of_Patients_Regd_At_GP_Practice_Single_Age1]
        WHERE 1 = 1 %s
      ),

      aggregated AS (
        SELECT
          Period,
          SUM(Size) AS Total_Size,

          100.0 * SUM(CASE WHEN SEX='Male' THEN Size ELSE 0 END)/NULLIF(SUM(Size),0) AS Pct_Male,
          100.0 * SUM(CASE WHEN SEX='Female' THEN Size ELSE 0 END)/NULLIF(SUM(Size),0) AS Pct_Female,

          100.0 * SUM(CASE WHEN CAST(CASE WHEN Age='95+' THEN 95 ELSE Age END AS INT) BETWEEN 0 AND 9 THEN Size ELSE 0 END)/NULLIF(SUM(Size),0) AS Pct_Age_0_9,
          100.0 * SUM(CASE WHEN CAST(CASE WHEN Age='95+' THEN 95 ELSE Age END AS INT) BETWEEN 10 AND 19 THEN Size ELSE 0 END)/NULLIF(SUM(Size),0) AS Pct_Age_10_19,
          100.0 * SUM(CASE WHEN CAST(CASE WHEN Age='95+' THEN 95 ELSE Age END AS INT) BETWEEN 20 AND 29 THEN Size ELSE 0 END)/NULLIF(SUM(Size),0) AS Pct_Age_20_29,
          100.0 * SUM(CASE WHEN CAST(CASE WHEN Age='95+' THEN 95 ELSE Age END AS INT) BETWEEN 30 AND 39 THEN Size ELSE 0 END)/NULLIF(SUM(Size),0) AS Pct_Age_30_39,
          100.0 * SUM(CASE WHEN CAST(CASE WHEN Age='95+' THEN 95 ELSE Age END AS INT) BETWEEN 40 AND 49 THEN Size ELSE 0 END)/NULLIF(SUM(Size),0) AS Pct_Age_40_49,
          100.0 * SUM(CASE WHEN CAST(CASE WHEN Age='95+' THEN 95 ELSE Age END AS INT) BETWEEN 50 AND 59 THEN Size ELSE 0 END)/NULLIF(SUM(Size),0) AS Pct_Age_50_59,
          100.0 * SUM(CASE WHEN CAST(CASE WHEN Age='95+' THEN 95 ELSE Age END AS INT) BETWEEN 60 AND 69 THEN Size ELSE 0 END)/NULLIF(SUM(Size),0) AS Pct_Age_60_69,
          100.0 * SUM(CASE WHEN CAST(CASE WHEN Age='95+' THEN 95 ELSE Age END AS INT) BETWEEN 70 AND 79 THEN Size ELSE 0 END)/NULLIF(SUM(Size),0) AS Pct_Age_70_79,
          100.0 * SUM(CASE WHEN CAST(CASE WHEN Age='95+' THEN 95 ELSE Age END AS INT) BETWEEN 80 AND 89 THEN Size ELSE 0 END)/NULLIF(SUM(Size),0) AS Pct_Age_80_89,
          100.0 * SUM(CASE WHEN CAST(CASE WHEN Age='95+' THEN 95 ELSE Age END AS INT) >= 90 THEN Size ELSE 0 END)/NULLIF(SUM(Size),0) AS Pct_Age_90_plus

        FROM base
        GROUP BY Period
      )

      SELECT * FROM aggregated
      ORDER BY Period
      ", date_group, date_filter)
      
    }
  }
  
  return(dbGetQuery(con, query))
}

#yearly <- get_gp_stats(con, "yearly")
#financial <- get_gp_stats(con, "financial")


monthly_overall <- get_gp_stats(
  con,
  period = "monthly",
  level = "overall",
  start_date = "2023-06-01",
  output_type = "counts"
  #,end_date = "2024-12-31"
)


monthly_practice <- get_gp_stats(
  con,
  period = "monthly",
  level = "practice",
  start_date = "2025-10-01",
  output_type = "counts"
  #,end_date = "2024-12-31"
)
