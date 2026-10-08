source("14_Summarise_IMD_Trends.R")
# Ten LSOAs in each of two dates and sources, with each decile represented.
history <- expand.grid(LSOA_Code = sprintf("E01%06d", 1:10),
  Period = as.Date(c("2023-07-01", "2024-07-01")),
  Source = c("Registered patients", "ONS population estimate"),
  stringsAsFactors = FALSE)
history$Population <- 100
lookup <- data.frame(LSOA_Code = sprintf("E01%06d", 1:10), IMD_Decile = 1:10)
x <- summarise_imd_trends(history, lookup)
stopifnot(nrow(x$trend) == 20, all(x$trend$Population == 200),
          all(x$trend$LSOA_Count == 2), length(x$lsoa_codes) == 10,
          all(x$coverage$Cohort_Population == 1000),
          all(x$coverage$Population_Excluded == 0))
# A code absent from one source/date is excluded from every trend point.
partial <- history[-1, ]
y <- summarise_imd_trends(partial, lookup)
stopifnot(length(y$lsoa_codes) == 9, !lookup$LSOA_Code[1] %in% y$lsoa_codes,
          all(y$coverage$Cohort_Population == 900),
          all(y$trend$Population[y$trend$Quintile == 1] == 100),
          all(y$coverage$English_Population ==
              y$coverage$Cohort_Population + y$coverage$Population_Excluded))
# Invalid IMD is excluded without silently assigning a quintile.
invalid <- lookup
invalid$IMD_Decile[10] <- NA
z <- summarise_imd_trends(history, invalid)
stopifnot(length(z$lsoa_codes) == 9, all(z$coverage$IMD_Eligible_Population == 900))
must_fail <- function(h, l, pattern) {
  err <- tryCatch(summarise_imd_trends(h, l), error = identity)
  stopifnot(inherits(err, "error"), grepl(pattern, conditionMessage(err)))
}
must_fail(rbind(history, history[1, ]), lookup, "Duplicate")
must_fail(history, rbind(lookup, lookup[1, ]), "unique")
bad <- history; bad$Population[1] <- -1
must_fail(bad, lookup, "nonnegative")
bad <- history; bad$Period[1] <- as.Date("2024-08-01")
must_fail(bad, lookup, "July")
must_fail(history[history$Source == "Registered patients", ], lookup, "both sources")
disjoint <- history[(history$Source == "Registered patients" & history$LSOA_Code == lookup$LSOA_Code[1]) |
                    (history$Source == "ONS population estimate" & history$LSOA_Code != lookup$LSOA_Code[1]), ]
must_fail(disjoint, lookup, "common LSOA cohort")
# Match July snapshots by year, even when their day differs.
paired <- data.frame(Source = c("Registered patients", "ONS population estimate",
  "Registered patients", "ONS population estimate", "Registered patients"),
  Period = as.Date(c("2015-07-01", "2015-07-31", "2016-07-01", "2016-07-01",
                    "2018-07-01")),
  Quintile = 1L, Population = c(110, 100, 5, 0, 120))
comparison <- compare_imd_trends(paired)
stopifnot(nrow(comparison) == 3,
          comparison$Raw_Difference[1] == 10,
          comparison$Pct_Difference[1] == 10,
          comparison$Raw_Difference[2] == 5,
          is.na(comparison$Pct_Difference[2]),
          is.na(comparison$ONS[3]),
          is.na(comparison$Raw_Difference[3]),
          is.na(comparison$Pct_Difference[3]),
          all(format(comparison$Period, "%m-%d") == "07-01"))
scaled <- paired; scaled$Population <- 10 * scaled$Population
scaled_comparison <- compare_imd_trends(scaled)
stopifnot(identical(scaled_comparison$Pct_Difference, comparison$Pct_Difference),
          isTRUE(all.equal(scaled_comparison$Raw_Difference,
                           comparison$Raw_Difference * 10)))
below <- paired; below$Population[1] <- 90
stopifnot(compare_imd_trends(below)$Pct_Difference[1] == -10)
duplicate <- paired[1, ]; duplicate$Period <- as.Date("2015-07-31")
err <- tryCatch(compare_imd_trends(rbind(paired, duplicate)), error = identity)
stopifnot(inherits(err, "error"), grepl("ambiguous", conditionMessage(err)))
# A retired 2011 code and its replacement 2021 code cannot enter a fixed-code
# cohort. The shared code is counted once at each source/date.
transition <- expand.grid(Period = as.Date(c("2023-07-01", "2024-07-01")),
  Source = c("Registered patients", "ONS population estimate"),
  stringsAsFactors = FALSE)
shared <- transition; shared$LSOA_Code <- "E01000001"; shared$Population <- 100
changed <- transition
changed$LSOA_Code <- ifelse(changed$Period < as.Date("2024-07-01"),
                          "E01000002", "E01000003")
changed$Population <- 50
transition_lookup <- data.frame(LSOA_Code = c("E01000001", "E01000003"),
                                IMD_Decile = c(1, 10))
cohort <- summarise_imd_trends(rbind(shared, changed), transition_lookup)
stopifnot(identical(cohort$lsoa_codes, "E01000001"),
          all(cohort$trend$Population == 100),
          all(cohort$coverage$English_Population == 150),
          all(cohort$coverage$Population_Excluded == 50))
cat("IMD trend and comparison checks passed.\n")


