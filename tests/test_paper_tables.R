# Run from the repository root: Rscript tests/test_paper_tables.R
# Uses base R only; no database or report packages are required.
source("11_Build_Paper_Tables.R")
snapshot <- as.Date("2024-07-01")
inputs <- list(
  snapshot_date = snapshot,
  national_registered = data.frame(Period = snapshot, Population = 130),
  national_ons = data.frame(Period = snapshot, Population = 90),
  practice_registered_snapshot = data.frame(
    Practice_Code = c("A", "B"), Registered = c(80, 45)),
  practice_demographics = data.frame(
    Period = snapshot, Sex = c("Female", "Male"),
    Age_Band = c("0-9", "90+"), Registered = c(80, 40)),
  ons_demographics = data.frame(
    Period = snapshot, Sex = c("Female", "Male"),
    Age_Band = c("0-9", "90+"), ONS = c(40, 50)),
  lsoa_registered = data.frame(
    Period = snapshot, LSOA_Code = c("E011", "E012", "W001", NA),
    Registered = c(60, 40, 20, 8)),
  lsoa_ons = data.frame(
    Period = snapshot, LSOA_Code = c("E011", "E013"), ONS = c(50, 40)),
  imd_lookup = data.frame(
    LSOA_Code = c("E011", "E012"), IMD_Decile = c(1, 10)),
  qualified_gp_workforce = data.frame(
    Period = as.Date("2024-07-31"),
    Practice_Code = c("A", "B", "C"), GP_FTE = c(2, NA, 1))
)
tables <- do.call(build_paper_tables, inputs)
cell <- function(label, column) {
  tables$table1[tables$table1$Characteristic == label, column]
}
stopifnot(
  cell("Source population total, n", "GP LSOA registrations") == "128",
  cell("English-residence population, n (%)", "GP LSOA registrations") == "100 (78.1%)",
  cell("Other/unassigned residence, n (%)", "GP LSOA registrations") == "8 (6.2%)",
  cell("English LSOAs absent from the other LSOA source, n", "GP LSOA registrations") == "1",
  cell("English LSOAs absent from the other LSOA source, n", "ONS population") == "1",
  cell("Outside extracted age/sex categories, n (%)", "GP practice registrations") == "10 (7.7%)",
  cell("No valid IMD decile, n (%)", "ONS population") == "40 (44.4%)",
  cell("Registrations without usable practice workforce data, n (%)", "GP practice registrations") == "50 (38.5%)",
  tables$table2_population[["Difference, n"]] == c("2", "40", "10"),
  tables$table2_population[["Difference, %"]] == c("1.54%", "44.44%", "11.11%"),
  tables$table2_workforce[["GP partner/salaried FTE"]] == c("3.0", "3.0"),
  tables$table2_workforce[["People per GP FTE"]] == c("43", "30"),
  tables$workforce_date == as.Date("2024-07-31")
)
must_fail <- function(args, pattern) {
  result <- tryCatch(do.call(build_paper_tables, args), error = identity)
  stopifnot(inherits(result, "error"), grepl(pattern, conditionMessage(result)))
}
bad <- inputs
bad$lsoa_registered$Registered[1] <- NA_real_
must_fail(bad, "missing, non-finite or negative")
bad <- inputs
bad$lsoa_ons <- rbind(bad$lsoa_ons, bad$lsoa_ons[1, ])
must_fail(bad, "duplicate keys")
bad <- inputs
bad$qualified_gp_workforce$GP_FTE <- 0
must_fail(bad, "must be positive")
bad <- inputs
bad$qualified_gp_workforce$Period[3] <- as.Date("2024-07-01")
must_fail(bad, "one workforce snapshot")
bad <- inputs
bad$national_ons$Population <- 91
must_fail(bad, "reconcile")
# Display rounding must not change the denominator used for the ratios.
fractional_fte <- inputs
fractional_fte$qualified_gp_workforce$GP_FTE[3] <- 0.96
rounded <- do.call(build_paper_tables, fractional_fte)
stopifnot(
  rounded$table2_workforce[["GP partner/salaried FTE"]] == c("3.0", "3.0"),
  rounded$table2_workforce[["People per GP FTE"]] == c("44", "30")
)
# A registration-source discrepancy can be negative.
negative <- inputs
negative$lsoa_registered$Registered[4] <- 20
negative_tables <- do.call(build_paper_tables, negative)
stopifnot(
  negative_tables$table2_population[["Difference, n"]][1] == "-10",
  negative_tables$table2_population[["Difference, %"]][1] == "-7.69%"
)
# A missing IMD classification is excluded, never coerced into a valid decile.
bad <- inputs
bad$imd_lookup$IMD_Decile[1] <- 1.5
fractional <- do.call(build_paper_tables, bad)
stopifnot(fractional$table1[
  fractional$table1$Characteristic == "No valid IMD decile, n (%)",
  "GP LSOA registrations"] == "60 (60.0%)")
cat("Paper table checks passed.\n")
