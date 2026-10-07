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
cat("IMD trend checks passed.\n")
