#function to get GP practice level data 
get_gp_stats <- function(
    con,
    period = c("monthly", "yearly", "financial"),
    level = c("practice", "overall"),
    start_date = NULL,
    end_date = NULL
) {
  
  period <- match.arg(period)
  level <- match.arg(level)
  
  date_group <- switch(
    period,
    monthly = "[Effective_Snapshot_Date]",
    yearly = "YEAR([Effective_Snapshot_Date])",
    financial = "
      CASE
        WHEN MONTH([Effective_Snapshot_Date]) >= 4 THEN
          CONCAT(
            YEAR([Effective_Snapshot_Date]),
            '/',
            RIGHT(CAST(YEAR([Effective_Snapshot_Date]) + 1 AS VARCHAR(4)), 2)
          )
        ELSE
          CONCAT(
            YEAR([Effective_Snapshot_Date]) - 1,
            '/',
            RIGHT(CAST(YEAR([Effective_Snapshot_Date]) AS VARCHAR(4)), 2)
          )
      END
    "
  )
  
  date_filter <- ""
  
  if (!is.null(start_date)) {
    date_filter <- paste0(
      date_filter,
      sprintf(" AND [Effective_Snapshot_Date] >= '%s'", start_date)
    )
  }
  
  if (!is.null(end_date)) {
    date_filter <- paste0(
      date_filter,
      sprintf(" AND [Effective_Snapshot_Date] <= '%s'", end_date)
    )
  }
  
  if (level == "practice") {
    
    query <- sprintf("
    WITH monthly AS (
      SELECT
        [GP_Practice_Code],
        %s AS Period,
        SUM([Size]) AS Total_Size,
        SUM(CASE
              WHEN CASE WHEN [Age] = '95+' THEN 95 ELSE CAST([Age] AS INT) END >= 65
              THEN [Size] ELSE 0
            END) AS Over65_Count,
        SUM(CASE WHEN [SEX] = 'Male' THEN [Size] ELSE 0 END) AS Male_Count
      FROM [Demography].[No_Of_Patients_Regd_At_GP_Practice_Single_Age1]
      WHERE 1 = 1 %s
      GROUP BY
        [GP_Practice_Code],
        %s,
        [Effective_Snapshot_Date]
    )

    SELECT
      [GP_Practice_Code],
      Period,
      AVG(Total_Size) AS Avg_Size,
      100.0 * SUM(Over65_Count) / NULLIF(SUM(Total_Size),0) AS Pct_Over_65,
      100.0 * SUM(Male_Count) / NULLIF(SUM(Total_Size),0) AS Pct_Male
    FROM monthly
    GROUP BY
      [GP_Practice_Code],
      Period
    ORDER BY
      [GP_Practice_Code],
      Period
    ",
                     date_group, date_filter, date_group)
    
  } else {
    
    query <- sprintf("
    WITH monthly AS (
      SELECT
        %s AS Period,
        SUM([Size]) AS Total_Size,
        SUM(CASE
              WHEN CASE WHEN [Age] = '95+' THEN 95 ELSE CAST([Age] AS INT) END >= 65
              THEN [Size] ELSE 0
            END) AS Over65_Count,
        SUM(CASE WHEN [SEX] = 'Male' THEN [Size] ELSE 0 END) AS Male_Count
      FROM [Demography].[No_Of_Patients_Regd_At_GP_Practice_Single_Age1]
      WHERE 1 = 1 %s
      GROUP BY
        %s,
        [Effective_Snapshot_Date]
    )

    SELECT
      Period,
      AVG(Total_Size) AS Avg_Size,
      100.0 * SUM(Over65_Count) / NULLIF(SUM(Total_Size),0) AS Pct_Over_65,
      100.0 * SUM(Male_Count) / NULLIF(SUM(Total_Size),0) AS Pct_Male
    FROM monthly
    GROUP BY
      Period
    ORDER BY
      Period
    ",
                     date_group, date_filter, date_group)
    
  }
  
  dbGetQuery(con, query)
}

#yearly <- get_gp_stats(con, "yearly")
#financial <- get_gp_stats(con, "financial")


monthly_overall <- get_gp_stats(
  con,
  period = "monthly",
  level = "overall",
  start_date = "2022-06-01"
  #,end_date = "2024-12-31"
)


monthly_practice <- get_gp_stats(
  con,
  period = "monthly",
  level = "practice",
  start_date = "2025-10-01"
  #,end_date = "2024-12-31"
)
