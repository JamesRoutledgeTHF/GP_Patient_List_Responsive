# Run from the repository root: Rscript tests/test_registration_coverage.R
# Base R only. These fixtures do not query the database.
source("12_Summarise_Registration_Coverage.R")
day <- as.Date("2024-07-01")
inputs <- list(
  snapshot_date = day,
  national_registered = data.frame(Period = c(day, as.Date("2023-07-01")),
                                   Population = c(130, 999)),
  lsoa_registered = data.frame(
    Period = day,
    LSOA_Code = c("E011", "E012", "E013", "W001", "W002", NA, "OTHER"),
    Registered = c(60, 30, 10, 12, 8, 5, 3)),
  imd_lookup = data.frame(LSOA_Code = c("E011", "E013"), IMD_Decile = c(1, NA))
)
x <- do.call(summarise_registration_coverage, inputs)
stopifnot(
  x$practice_total == 130, x$lsoa_total == 128,
  x$source_difference == 2,
  x$welsh_lsoa_count == 2, x$welsh_patients == 20,
  x$other_patients == 8, x$english_patients == 100,
  x$english_lsoas_without_imd == 2, x$english_patients_without_imd == 40,
  x$imd_patients == 60, x$lsoa_imd_difference == 68,
  x$practice_imd_difference == 70,
  x$lsoa_imd_difference == x$welsh_patients + x$other_patients +
    x$english_patients_without_imd,
  x$practice_imd_difference == x$source_difference + x$lsoa_imd_difference,
  abs(x$source_difference_pct - 100 * 2 / 130) < 1e-10
)
# Complete English coverage produces no additional IMD loss.
complete <- inputs
complete$imd_lookup <- data.frame(LSOA_Code = c("E011", "E012", "E013"),
                                  IMD_Decile = c(1, 5, 10))
y <- do.call(summarise_registration_coverage, complete)
stopifnot(y$english_patients_without_imd == 0, y$imd_patients == 100,
          y$lsoa_imd_difference == 28)
# A Welsh decile from a separate index must not enter the English analysis.
welsh_lookup <- complete
welsh_lookup$imd_lookup <- rbind(welsh_lookup$imd_lookup,
  data.frame(LSOA_Code = "W001", IMD_Decile = 1))
stopifnot(do.call(summarise_registration_coverage, welsh_lookup)$imd_patients == 100)
# Do not turn a source increase into a claimed source loss.
complete$national_registered$Population[1] <- 120
y <- do.call(summarise_registration_coverage, complete)
stopifnot(y$source_difference == -8, y$practice_imd_difference == 20)
must_fail <- function(args, pattern) {
  err <- tryCatch(do.call(summarise_registration_coverage, args), error = identity)
  stopifnot(inherits(err, "error"), grepl(pattern, conditionMessage(err)))
}
bad <- inputs
bad$lsoa_registered$Registered[1] <- NA_real_
must_fail(bad, "missing, non-finite or negative")
bad <- inputs
bad$imd_lookup <- rbind(bad$imd_lookup, bad$imd_lookup[1, ])
must_fail(bad, "unique LSOA keys")
# Fractional or out-of-range deciles are not valid IMD classifications.
bad <- inputs
bad$imd_lookup$IMD_Decile[1] <- 1.5
stopifnot(do.call(summarise_registration_coverage, bad)$imd_patients == 0)
cat("Registration coverage checks passed.\n")
