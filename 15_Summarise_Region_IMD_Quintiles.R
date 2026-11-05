# Same-snapshot residence comparison, independent of the historical IMD cohort.
# Base R so the aggregation and exclusion accounting can be checked without SQL.
summarise_region_imd_quintiles <- function(registered, ons, geography, imd) {
  required <- list(
    registered = c("LSOA_Code", "Period", "Registered"),
    ons = c("LSOA_Code", "Period", "ONS"),
    geography = c("LSOA21CD", "NHSER26CD", "NHSER26NM"),
    imd = c("LSOA_Code", "IMD_Decile")
  )
  inputs <- list(registered = registered, ons = ons, geography = geography, imd = imd)
  for (name in names(inputs)) {
    if (!all(required[[name]] %in% names(inputs[[name]]))) {
      stop("Missing fields in regional IMD ", name, ".")
    }
    key <- required[[name]][1]
    if (anyNA(inputs[[name]][[key]]) || anyDuplicated(inputs[[name]][[key]])) {
      # Non-English unknown residence codes may be present in the raw extract.
      if (name != "registered") stop("Duplicate or missing regional IMD keys in ", name, ".")
      english <- grepl("^E01", inputs[[name]][[key]])
      if (anyDuplicated(inputs[[name]][[key]][english])) {
        stop("Duplicate English regional IMD registration keys.")
      }
    }
  }
  registered <- registered[!is.na(registered$LSOA_Code) &
    grepl("^E01", registered$LSOA_Code), required$registered, drop = FALSE]
  ons <- ons[grepl("^E01", ons$LSOA_Code), required$ons, drop = FALSE]
  periods <- unique(as.Date(c(as.character(registered$Period), as.character(ons$Period))))
  if (length(periods) != 1L || anyNA(periods)) {
    stop("Regional IMD comparison requires one common snapshot date.")
  }
  for (name in c("registered", "ons")) {
    values <- if (name == "registered") registered$Registered else ons$ONS
    if (!is.numeric(values) || any(!is.finite(values)) || any(values < 0)) {
      stop("Invalid population counts in regional IMD ", name, ".")
    }
  }
  x <- merge(registered, ons, by = c("LSOA_Code", "Period"), all = TRUE)
  g <- match(x$LSOA_Code, geography$LSOA21CD)
  if (anyNA(g)) stop("English LSOAs are missing NHS region assignments.")
  x$NHSER26CD <- geography$NHSER26CD[g]
  x$NHSER26NM <- geography$NHSER26NM[g]
  if (anyNA(x[c("NHSER26CD", "NHSER26NM")]) ||
      any(x$NHSER26CD == "" | x$NHSER26NM == "")) {
    stop("Missing NHS region labels.")
  }
  imd_deciles <- suppressWarnings(as.numeric(as.character(imd$IMD_Decile)))
  x$IMD_Decile <- imd_deciles[match(x$LSOA_Code, imd$LSOA_Code)]
  x$Coverage <- ifelse(is.na(x$IMD_Decile) | !x$IMD_Decile %in% 1:10,
    "No valid IMD", ifelse(is.na(x$Registered), "Missing registration source",
      ifelse(is.na(x$ONS), "Missing ONS source", "Included")))
  included <- x[x$Coverage == "Included", , drop = FALSE]
  if (!nrow(included)) stop("No paired LSOAs with valid IMD for the regional comparison.")
  included$Quintile <- as.integer(ceiling(included$IMD_Decile / 2))
  totals <- aggregate(cbind(Registered, ONS) ~ NHSER26CD + Quintile, included, sum)
  lsoa_n <- aggregate(LSOA_Code ~ NHSER26CD + Quintile, included, length)
  names(lsoa_n)[3] <- "LSOA_Count"
  totals <- merge(totals, lsoa_n, by = c("NHSER26CD", "Quintile"))
  regions <- unique(x[c("NHSER26CD", "NHSER26NM")])
  if (anyDuplicated(regions$NHSER26CD)) stop("Conflicting NHS region names.")
  grid <- merge(regions, data.frame(Quintile = 1:5), by = NULL)
  comparison <- merge(grid, totals, by = c("NHSER26CD", "Quintile"), all.x = TRUE)
  comparison$Period <- periods[1]
  comparison$Raw_Difference <- comparison$Registered - comparison$ONS
  comparison$Pct_Difference <- ifelse(!is.na(comparison$ONS) & comparison$ONS > 0,
    100 * comparison$Raw_Difference / comparison$ONS, NA_real_)
  comparison <- comparison[order(comparison$NHSER26NM, comparison$Quintile), ]
  # Each code appears in exactly one coverage category. Missing source counts
  # remain unknown rather than being represented as zero population.
  sum_available <- function(values) {
    if (all(is.na(values))) NA_real_ else sum(values, na.rm = TRUE)
  }
  coverage_keys <- unique(x[c("NHSER26CD", "NHSER26NM", "Coverage")])
  coverage <- do.call(rbind, lapply(seq_len(nrow(coverage_keys)), function(i) {
    rows <- x$NHSER26CD == coverage_keys$NHSER26CD[i] &
      x$Coverage == coverage_keys$Coverage[i]
    cbind(coverage_keys[i, ], data.frame(LSOA_Count = sum(rows),
      Registered = sum_available(x$Registered[rows]),
      ONS = sum_available(x$ONS[rows])))
  }))
  list(comparison = comparison, coverage = coverage)
}
