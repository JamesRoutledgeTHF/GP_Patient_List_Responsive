# Reconcile registered-patient counts before any ONS or geography join.
# Welsh/other residence exclusions and additional English IMD exclusions
# form disjoint parts of the LSOA-to-deprivation reduction.
summarise_registration_coverage <- function(
  national_registered, lsoa_registered, imd_lookup, snapshot_date
) {
  snapshot_date <- as.Date(snapshot_date)
  if (length(snapshot_date) != 1L || is.na(snapshot_date)) {
    stop("Registration coverage requires one valid snapshot date.")
  }
  snapshot <- function(x) {
    x[!is.na(x$Period) & as.Date(x$Period) == snapshot_date, , drop = FALSE]
  }
  check_counts <- function(x, label) {
    if (!is.numeric(x) || any(!is.finite(x)) || any(x < 0)) {
      stop(label, " contains missing, non-finite or negative counts.")
    }
  }
  national <- snapshot(national_registered)
  registered <- snapshot(lsoa_registered)
  if (nrow(national) != 1L || nrow(registered) == 0L) {
    stop("Both registration sources must be present at the requested snapshot.")
  }
  check_counts(national$Population, "Practice total")
  check_counts(registered$Registered, "LSOA registration extract")
  if (national$Population <= 0 || sum(registered$Registered) <= 0) {
    stop("Both registration totals must be positive.")
  }
  if (anyDuplicated(registered$LSOA_Code) || anyDuplicated(imd_lookup$LSOA_Code)) {
    stop("Registration coverage requires unique LSOA keys in each source.")
  }
  english <- !is.na(registered$LSOA_Code) & grepl("^E01", registered$LSOA_Code)
  welsh <- !is.na(registered$LSOA_Code) & grepl("^W0", registered$LSOA_Code)
  other <- !english & !welsh
  imd_match <- match(registered$LSOA_Code, imd_lookup$LSOA_Code)
  decile <- suppressWarnings(as.numeric(as.character(
    imd_lookup$IMD_Decile[imd_match])))
  eligible <- english & decile %in% 1:10
  english_without_imd <- english & !eligible
  english_absent_imd <- english & is.na(imd_match)
  english_invalid_imd <- english & !is.na(imd_match) & !eligible
  linkage_status <- rep("Other or unassigned residence", nrow(registered))
  linkage_status[welsh] <- "Welsh residence: separate deprivation index"
  linkage_status[eligible] <- "English LSOA: valid IMD decile"
  linkage_status[english_absent_imd] <- "English LSOA: absent from IMD lookup"
  linkage_status[english_invalid_imd] <- "English LSOA: invalid or missing IMD decile"
  linkage_audit <- data.frame(
    LSOA_Code = as.character(registered$LSOA_Code),
    Registered = registered$Registered,
    Linkage_Status = linkage_status,
    IMD_Decile = decile,
    stringsAsFactors = FALSE
  )
  practice_total <- national$Population
  lsoa_total <- sum(registered$Registered)
  english_total <- sum(registered$Registered[english])
  wales_total <- sum(registered$Registered[welsh])
  other_total <- sum(registered$Registered[other])
  imd_total <- sum(registered$Registered[eligible])
  english_imd_excluded <- sum(registered$Registered[english_without_imd])
  source_difference <- practice_total - lsoa_total
  lsoa_imd_difference <- lsoa_total - imd_total
  practice_imd_difference <- practice_total - imd_total
  if (abs(lsoa_imd_difference - wales_total - other_total - english_imd_excluded) > 0.5 ||
      abs(practice_imd_difference - source_difference - lsoa_imd_difference) > 0.5) {
    stop("Registration coverage reductions do not reconcile.")
  }
  list(
    practice_total = practice_total,
    lsoa_total = lsoa_total,
    source_difference = source_difference,
    source_difference_pct = 100 * source_difference / practice_total,
    welsh_lsoa_count = sum(welsh),
    welsh_patients = wales_total,
    welsh_patients_pct = 100 * wales_total / lsoa_total,
    other_patients = other_total,
    english_patients = english_total,
    english_lsoas_without_imd = sum(english_without_imd),
    english_patients_without_imd = english_imd_excluded,
    english_patients_absent_from_imd = sum(registered$Registered[english_absent_imd]),
    english_patients_invalid_imd = sum(registered$Registered[english_invalid_imd]),
    linkage_audit = linkage_audit,
    english_imd_excluded_pct = if (english_total > 0)
      100 * english_imd_excluded / english_total else NA_real_,
    imd_patients = imd_total,
    lsoa_imd_difference = lsoa_imd_difference,
    lsoa_imd_difference_pct = 100 * lsoa_imd_difference / lsoa_total,
    practice_imd_difference = practice_imd_difference,
    practice_imd_difference_pct = 100 * practice_imd_difference / practice_total
  )
}
