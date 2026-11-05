# Run from repository root: Rscript tests/test_region_imd_quintiles.R
source("15_Summarise_Region_IMD_Quintiles.R")
codes <- sprintf("E01%06d", 1:7)
registered <- data.frame(LSOA_Code = c(codes[c(1:5, 7)], "W01000001", NA),
  Period = as.Date("2024-07-01"),
  Registered = c(100, 90, 80, 20, 30, 40, 500, 900))
ons <- data.frame(LSOA_Code = codes[c(1:4, 6:7)],
  Period = as.Date("2024-07-01"), ONS = c(50, 100, 100, 40, 10, 50))
geography <- data.frame(LSOA21CD = codes,
  NHSER26CD = c("A", "A", "A", "B", "B", "B", "B"),
  NHSER26NM = c("Region A", "Region A", "Region A", rep("Region B", 4)))
imd <- data.frame(LSOA_Code = codes, IMD_Decile = c(1, 2, 3, 10, 5, 7, NA))
result <- summarise_region_imd_quintiles(registered, ons, geography, imd)
x <- result$comparison
stopifnot(nrow(x) == 10L, !anyDuplicated(x[c("NHSER26CD", "Quintile")]))
q1 <- x[x$NHSER26CD == "A" & x$Quintile == 1, ]
stopifnot(q1$Registered == 190, q1$ONS == 150, q1$LSOA_Count == 2L,
  abs(q1$Pct_Difference - 100 * 40 / 150) < 1e-10)
q5 <- x[x$NHSER26CD == "B" & x$Quintile == 5, ]
stopifnot(q5$Registered == 20, q5$ONS == 40, q5$Pct_Difference == -50)
missing <- x[x$NHSER26CD == "B" & x$Quintile == 3, ]
stopifnot(is.na(missing$Registered), is.na(missing$ONS), is.na(missing$Pct_Difference))
coverage <- result$coverage
stopifnot(sum(coverage$LSOA_Count) == 7L,
  sum(coverage$Registered, na.rm = TRUE) == 360,
  sum(coverage$ONS, na.rm = TRUE) == 350,
  sum(x$Registered, na.rm = TRUE) == 290, sum(x$ONS, na.rm = TRUE) == 290)
stopifnot(setequal(coverage$Coverage,
  c("Included", "Missing registration source", "Missing ONS source", "No valid IMD")))
zero_ons <- ons
zero_ons$ONS[zero_ons$LSOA_Code == codes[4]] <- 0
zero <- summarise_region_imd_quintiles(registered, zero_ons, geography, imd)$comparison
stopifnot(is.na(zero$Pct_Difference[zero$NHSER26CD == "B" & zero$Quintile == 5]))
must_fail <- function(expr) {
  error <- tryCatch(force(expr), error = identity)
  stopifnot(inherits(error, "error"))
}
must_fail(summarise_region_imd_quintiles(rbind(registered, registered[1, ]), ons, geography, imd))
must_fail(summarise_region_imd_quintiles(registered, ons, geography[-1, ], imd))
must_fail(summarise_region_imd_quintiles(registered, ons, geography, rbind(imd, imd[1, ])))
bad <- registered
bad$Registered[1] <- -1
must_fail(summarise_region_imd_quintiles(bad, ons, geography, imd))
bad <- ons
bad$Period[1] <- as.Date("2023-07-01")
must_fail(summarise_region_imd_quintiles(registered, bad, geography, imd))
cat("Regional IMD quintile checks passed.\n")
