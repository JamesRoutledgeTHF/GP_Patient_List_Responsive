# Build the paper's descriptive tables from the report's existing extracts.
# This function does not query the database or replace missing counts with zero.
build_paper_tables <- function(
  snapshot_date, national_registered, national_ons,
  practice_registered_snapshot, practice_demographics, ons_demographics,
  lsoa_registered, lsoa_ons, imd_lookup, qualified_gp_workforce
) {
  snapshot_date <- as.Date(snapshot_date)
  if (length(snapshot_date) != 1L || is.na(snapshot_date)) {
    stop("Paper tables require one valid snapshot date.")
  }
  at_snapshot <- function(x) {
    x[!is.na(x$Period) & as.Date(x$Period) == snapshot_date, , drop = FALSE]
  }
  check_counts <- function(x, label) {
    if (!is.numeric(x) || any(!is.finite(x)) || any(x < 0)) {
      stop(label, " contains missing, non-finite or negative population counts.")
    }
  }
  unique_key <- function(x, label) {
    if (anyDuplicated(x)) stop(label, " contains duplicate keys.")
  }
  fmt_n <- function(x, accuracy = 1) {
    format(round(x / accuracy) * accuracy, big.mark = ",", trim = TRUE,
           scientific = FALSE, nsmall = if (accuracy < 1) 1 else 0)
  }
  fmt_np <- function(x, denominator) {
    if (denominator <= 0) return(paste0(fmt_n(x), " (NE)"))
    paste0(fmt_n(x), " (", sprintf("%.1f", 100 * x / denominator), "%)")
  }
  row <- function(label, practice = "NE", lsoa = "NE", ons = "NE") {
    data.frame(Characteristic = label, Practice = practice, LSOA = lsoa,
               ONS = ons, stringsAsFactors = FALSE)
  }
  practice_national <- at_snapshot(national_registered)
  ons_national <- at_snapshot(national_ons)
  if (nrow(practice_national) != 1L || nrow(ons_national) != 1L) {
    stop("Paper tables require one national total per source at the snapshot.")
  }
  practice_total <- practice_national$Population
  ons_total <- ons_national$Population
  check_counts(c(practice_total, ons_total), "National totals")
  if (practice_total <= 0 || ons_total <= 0) stop("National totals must be positive.")

  lsoa_registered <- at_snapshot(lsoa_registered)
  lsoa_ons <- at_snapshot(lsoa_ons)
  if (nrow(lsoa_registered) == 0L || nrow(lsoa_ons) == 0L) {
    stop("Paper tables require both LSOA extracts at the snapshot.")
  }
  unique_key(lsoa_registered$LSOA_Code, "Registered LSOA extract")
  unique_key(lsoa_ons$LSOA_Code, "ONS LSOA extract")
  check_counts(lsoa_registered$Registered, "Registered LSOA extract")
  check_counts(lsoa_ons$ONS, "ONS LSOA extract")
  english_code <- function(x) !is.na(x) & grepl("^E01", x)
  welsh_code <- function(x) !is.na(x) & grepl("^W0", x)
  registered_english <- lsoa_registered[english_code(lsoa_registered$LSOA_Code), ]
  ons_english <- lsoa_ons[english_code(lsoa_ons$LSOA_Code), ]
  if (nrow(registered_english) == 0L || nrow(ons_english) == 0L ||
      nrow(ons_english) != nrow(lsoa_ons)) {
    stop("Paper tables require English LSOAs in both sources and England-only ONS data.")
  }
  lsoa_total <- sum(lsoa_registered$Registered)
  english_total <- sum(registered_english$Registered)
  if (lsoa_total <= 0 || english_total <= 0 ||
      abs(sum(ons_english$ONS) - ons_total) > 0.5) {
    stop("Paper table LSOA totals are invalid or do not reconcile with the ONS national total.")
  }
  wales_total <- sum(lsoa_registered$Registered[welsh_code(lsoa_registered$LSOA_Code)])
  other_total <- lsoa_total - english_total - wales_total

  practices <- practice_registered_snapshot
  unique_key(practices$Practice_Code, "Practice snapshot")
  check_counts(practices$Registered, "Practice snapshot")
  valid_practice <- !is.na(practices$Practice_Code) &
    nzchar(trimws(practices$Practice_Code))
  practices <- practices[valid_practice, , drop = FALSE]
  unassigned_practice_total <- practice_total - sum(practices$Registered)
  if (unassigned_practice_total < -0.5) {
    stop("Practice-level registrations exceed the national practice total.")
  }

  workforce <- qualified_gp_workforce[
    !is.na(qualified_gp_workforce$Period) &
      format(as.Date(qualified_gp_workforce$Period), "%Y-%m") ==
      format(snapshot_date, "%Y-%m"), , drop = FALSE
  ]
  if (nrow(workforce) == 0L || length(unique(workforce$Period)) != 1L) {
    stop("Paper tables require one workforce snapshot within the selected month.")
  }
  unique_key(workforce$Practice_Code, "Workforce snapshot")
  if (any(!is.na(workforce$GP_FTE) &
          (!is.finite(workforce$GP_FTE) | workforce$GP_FTE < 0))) {
    stop("The workforce extract contains invalid GP FTE values.")
  }
  gp_fte <- sum(workforce$GP_FTE, na.rm = TRUE)
  if (!is.finite(gp_fte) || gp_fte <= 0) stop("The GP FTE total must be positive.")
  usable_workforce_codes <- workforce$Practice_Code[!is.na(workforce$GP_FTE)]
  matched_workforce <- practices$Practice_Code %in% usable_workforce_codes
  registrations_without_workforce <- unassigned_practice_total +
    sum(practices$Registered[!matched_workforce])

  coverage <- do.call(rbind, list(
    row("Population definition", "Registered with English practices",
        "Registrations by residence LSOA", "Usual residents of England"),
    row("Source population total, n", fmt_n(practice_total),
        fmt_n(lsoa_total), fmt_n(ons_total)),
    row("English-residence population, n (%)", "NE",
        fmt_np(english_total, lsoa_total), fmt_np(ons_total, ons_total)),
    row("Welsh residence, n (%)", "NE", fmt_np(wales_total, lsoa_total), "NA"),
    row("Other/unassigned residence, n (%)", "NE", fmt_np(other_total, lsoa_total), "NA"),
    row("Practices with identifiable codes, n", fmt_n(nrow(practices)), "NE", "NA"),
    row("Registrations without an identifiable practice code, n (%)",
        fmt_np(unassigned_practice_total, practice_total), "NE", "NA"),
    row("English LSOAs present in extract, n", "NE",
        fmt_n(nrow(registered_english)), fmt_n(nrow(ons_english))),
    row("English LSOAs absent from the other LSOA source, n", "NA",
        fmt_n(sum(!registered_english$LSOA_Code %in% ons_english$LSOA_Code)),
        fmt_n(sum(!ons_english$LSOA_Code %in% registered_english$LSOA_Code))),
    row("Practices linked to usable workforce data, n",
        fmt_n(sum(matched_workforce)), "NA", "NA"),
    row("Registrations without usable practice workforce data, n (%)",
        fmt_np(registrations_without_workforce, practice_total), "NA", "NA")
  ))

  practice_demographics <- at_snapshot(practice_demographics)
  ons_demographics <- at_snapshot(ons_demographics)
  if (nrow(practice_demographics) == 0L || nrow(ons_demographics) == 0L) {
    stop("Paper tables require both demographic extracts at the snapshot.")
  }
  check_counts(practice_demographics$Registered, "Practice demographic extract")
  check_counts(ons_demographics$ONS, "ONS demographic extract")
  age_levels <- c("0-9", "10-19", "20-29", "30-39", "40-49", "50-59",
                  "60-69", "70-79", "80-89", "90+")
  classified <- function(x) {
    x$Sex %in% c("Female", "Male") & x$Age_Band %in% age_levels
  }
  practice_demo <- practice_demographics[classified(practice_demographics), ]
  ons_demo <- ons_demographics[classified(ons_demographics), ]
  unique_key(paste(practice_demo$Sex, practice_demo$Age_Band), "Practice demographics")
  unique_key(paste(ons_demo$Sex, ons_demo$Age_Band), "ONS demographics")
  practice_demo_missing <- practice_total - sum(practice_demo$Registered)
  ons_demo_missing <- ons_total - sum(ons_demo$ONS)
  if (practice_demo_missing < -0.5 || ons_demo_missing < -0.5) {
    stop("Extracted age/sex counts exceed their source national total.")
  }
  demographics <- row("Outside extracted age/sex categories, n (%)",
                       fmt_np(practice_demo_missing, practice_total), "NE",
                       fmt_np(ons_demo_missing, ons_total))
  for (sex in c("Female", "Male")) {
    demographics <- rbind(demographics, row(paste0("Sex: ", sex, ", n (%)"),
      fmt_np(sum(practice_demo$Registered[practice_demo$Sex == sex]), practice_total),
      "NE", fmt_np(sum(ons_demo$ONS[ons_demo$Sex == sex]), ons_total)))
  }
  for (age in age_levels) {
    demographics <- rbind(demographics, row(paste0("Age ", age, ", n (%)"),
      fmt_np(sum(practice_demo$Registered[practice_demo$Age_Band == age]), practice_total),
      "NE", fmt_np(sum(ons_demo$ONS[ons_demo$Age_Band == age]), ons_total)))
  }

  unique_key(imd_lookup$LSOA_Code, "IMD lookup")
  registered_imd <- suppressWarnings(as.numeric(as.character(
    imd_lookup$IMD_Decile[match(registered_english$LSOA_Code, imd_lookup$LSOA_Code)])))
  ons_imd <- suppressWarnings(as.numeric(as.character(
    imd_lookup$IMD_Decile[match(ons_english$LSOA_Code, imd_lookup$LSOA_Code)])))
  deprivation <- row("No valid IMD decile, n (%)", "NE",
    fmt_np(sum(registered_english$Registered[!registered_imd %in% 1:10]), english_total),
    fmt_np(sum(ons_english$ONS[!ons_imd %in% 1:10]), ons_total))
  for (decile in 1:10) {
    label <- paste0("IMD decile ", decile,
                    if (decile == 1) " (most deprived)" else
                    if (decile == 10) " (least deprived)" else "", ", n (%)")
    deprivation <- rbind(deprivation, row(label, "NE",
      fmt_np(sum(registered_english$Registered[registered_imd %in% decile]), english_total),
      fmt_np(sum(ons_english$ONS[ons_imd %in% decile]), ons_total)))
  }
  table1 <- rbind(coverage, demographics, deprivation)
  names(table1) <- c("Characteristic", "GP practice registrations",
                    "GP LSOA registrations", "ONS population")

  table2_population <- data.frame(
    Comparison = c("Practice minus LSOA (all residence codes)",
                   "Practice minus ONS", "LSOA (English residence) minus ONS"),
    First_Total = c(practice_total, practice_total, english_total),
    Second_Total = c(lsoa_total, ons_total, ons_total),
    stringsAsFactors = FALSE
  )
  table2_population$Difference <- table2_population$First_Total -
    table2_population$Second_Total
  table2_population$Percentage <- 100 * table2_population$Difference /
    c(practice_total, ons_total, ons_total)
  table2_population$First_Total <- fmt_n(table2_population$First_Total)
  table2_population$Second_Total <- fmt_n(table2_population$Second_Total)
  table2_population$Difference <- fmt_n(table2_population$Difference)
  table2_population$Percentage <- sprintf("%.2f%%", table2_population$Percentage)
  names(table2_population) <- c("Comparison", "First total, n", "Second total, n",
                               "Difference, n", "Difference, %")
  table2_workforce <- data.frame(
    `Population basis` = c("GP practice registrations", "ONS residents"),
    `GP partner/salaried FTE` = rep(fmt_n(gp_fte, 0.1), 2),
    `People per GP FTE` = fmt_n(c(practice_total, ons_total) / gp_fte),
    check.names = FALSE
  )
  imd_source_date <- if ("IMD_Source_Date" %in% names(imd_lookup)) {
    paste(sort(unique(as.character(imd_lookup$IMD_Source_Date))), collapse = ", ")
  } else "not supplied"
  list(table1 = table1, table2_population = table2_population,
       table2_workforce = table2_workforce,
       workforce_date = seq(as.Date(format(snapshot_date, "%Y-%m-01")),
                            by = "month", length.out = 2)[2] - 1,
       imd_source_date = imd_source_date,
       missing_workforce_rows = sum(is.na(workforce$GP_FTE)))
}
