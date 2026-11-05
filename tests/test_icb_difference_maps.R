source("16_Classify_ICB_Map_Deciles.R")
source("19_Prepare_ICB_Rate_Maps.R")
x <- data.frame(ICB_Key = c("A", "B"), Registered = c(120, 80),
  ONS = c(100, 100), GP_FTE = c(2, 4), Total_Payments = c(1000, 1000))
x$Registered_FTE <- x$Registered / x$GP_FTE
x$ONS_FTE <- x$ONS / x$GP_FTE
x$Payment_Registered <- x$Total_Payments / x$Registered
x$Payment_ONS <- x$Total_Payments / x$ONS
gp <- prepare_icb_difference_map(x, c("A", "B", "C"),
  "Registered_FTE", "ONS_FTE", "registered-minus-ons")$data
gp <- gp[match(c("A", "B", "C"), gp$ICB_Key), ]
stopifnot(gp$Map_Difference[1] == 10, gp$Map_Difference[2] == -5,
  is.na(gp$Map_Difference[3]), gp$Map_Decile_Label[3] == "No comparable data",
  identical(gp$GP_FTE[1:2], x$GP_FTE), gp$Registered[1] == 120,
  gp$ONS[1] == 100, gp$Map_Decile[1] == 10L, gp$Map_Decile[2] == 1L)
payments <- prepare_icb_difference_map(x, c("A", "B"),
  "Payment_Registered", "Payment_ONS", "ons-minus-registered")$data
payments <- payments[match(c("A", "B"), payments$ICB_Key), ]
stopifnot(abs(payments$Map_Difference[1] - (10 - 1000 / 120)) < 1e-12,
  payments$Map_Difference[2] == -2.5,
  all(payments$Total_Payments == 1000),
  all(payments$Difference_Definition == "ons-minus-registered"))
# A missing rate never turns into zero difference.
missing <- x
missing$Registered_FTE[1] <- NA_real_
m <- prepare_icb_difference_map(missing, c("A", "B"),
  "Registered_FTE", "ONS_FTE")$data
stopifnot(is.na(m$Map_Difference[m$ICB_Key == "A"]))
must_fail <- function(expr) {
  error <- tryCatch(force(expr), error = identity)
  stopifnot(inherits(error, "error"))
}
must_fail(prepare_icb_difference_map(rbind(x, x[1, ]), c("A", "B"),
  "Registered_FTE", "ONS_FTE"))
must_fail(prepare_icb_difference_map(x, "A", "Registered_FTE", "ONS_FTE"))
must_fail(prepare_icb_difference_map(x, c("A", "B"), "missing", "ONS_FTE"))
cat("ICB difference map checks passed.\n")
