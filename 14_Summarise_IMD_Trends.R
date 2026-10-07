# Fixed-IMD, balanced-LSOA July trends. Uses base R for independent testing.
summarise_imd_trends <- function(history, imd_lookup) {
  required <- c("LSOA_Code", "Period", "Source", "Population")
  if (!all(required %in% names(history)) || !nrow(history)) {
    stop("IMD trends require LSOA, date, source and population histories.")
  }
  if (!all(c("LSOA_Code", "IMD_Decile") %in% names(imd_lookup)) ||
      anyNA(imd_lookup$LSOA_Code) || anyDuplicated(imd_lookup$LSOA_Code)) {
    stop("IMD lookup must have unique nonmissing LSOA codes.")
  }
  history$Period <- as.Date(history$Period)
  sources <- c("Registered patients", "ONS population estimate")
  if (anyNA(history[required]) || !is.numeric(history$Population) ||
      any(!is.finite(history$Population)) || any(history$Population < 0) ||
      !setequal(unique(history$Source), sources) ||
      any(format(history$Period, "%m") != "07")) {
    stop("IMD trends require finite nonnegative July counts for both sources.")
  }
  if (anyDuplicated(history[c("LSOA_Code", "Period", "Source")])) {
    stop("Duplicate LSOA/source/date records would double-count trend populations.")
  }
  history <- history[grepl("^E01", history$LSOA_Code), , drop = FALSE]
  deciles <- suppressWarnings(as.numeric(as.character(imd_lookup$IMD_Decile)))
  history$IMD_Decile <- deciles[match(history$LSOA_Code, imd_lookup$LSOA_Code)]
  valid <- !is.na(history$IMD_Decile) & history$IMD_Decile %in% 1:10
  eligible <- history[valid, , drop = FALSE]
  if (!all(sources %in% eligible$Source)) {
    stop("No valid English IMD history is available for one or both sources.")
  }
  # Each LSOA must occur in every available source/date combination.
  periods <- unique(history[c("Source", "Period")])
  present <- table(eligible$LSOA_Code)
  cohort <- names(present)[present == nrow(periods)]
  if (!length(cohort)) {
    stop("No common LSOA cohort across the histories. Check geography and IMD linkage.")
  }
  balanced <- eligible[eligible$LSOA_Code %in% cohort, , drop = FALSE]
  balanced$Quintile <- as.integer(ceiling(balanced$IMD_Decile / 2))
  trend <- aggregate(Population ~ Source + Period + Quintile, balanced, sum)
  counts <- aggregate(LSOA_Code ~ Source + Period + Quintile, balanced, length)
  names(counts)[names(counts) == "LSOA_Code"] <- "LSOA_Count"
  trend <- merge(trend, counts, by = c("Source", "Period", "Quintile"))
  trend <- trend[order(trend$Source, trend$Period, trend$Quintile), ]
  coverage <- do.call(rbind, lapply(seq_len(nrow(periods)), function(i) {
    selected <- history$Source == periods$Source[i] & history$Period == periods$Period[i]
    all <- history[selected, , drop = FALSE]
    covered <- all$LSOA_Code %in% cohort
    data.frame(Source = periods$Source[i], Period = periods$Period[i],
      English_Population = sum(all$Population),
      IMD_Eligible_Population = sum(all$Population[!is.na(all$IMD_Decile) &
                                                 all$IMD_Decile %in% 1:10]),
      Cohort_Population = sum(all$Population[covered]),
      Population_Excluded = sum(all$Population[!covered]),
      Cohort_LSOAs = sum(covered))
  }))
  coverage <- coverage[order(coverage$Source, coverage$Period), ]
  list(trend = trend, coverage = coverage, lsoa_codes = cohort)
}
