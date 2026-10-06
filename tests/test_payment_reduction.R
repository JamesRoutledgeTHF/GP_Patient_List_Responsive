# Run from the repository root: Rscript tests/test_payment_reduction.R
source("13_Model_Payment_Reduction.R")
example <- data.frame(Total_Payments = c(1650000, 16500, 16500, 0),
                      Registered = c(10000, 100, 100, 100),
                      ONS = c(9000, 100, 120, 80))
x <- model_payment_reduction(example)
stopifnot(
  x$Payment_Per_Registered[1] == 165,
  x$Registrations_Removed == c(1000, 0, 0, 20),
  x$Potential_Reduction == c(165000, 0, 0, 0),
  x$Remaining_Payments == c(1485000, 16500, 16500, 0),
  x$Reduction_Pct == c(10, 0, 0, 0),
  x$Total_Payments == x$Remaining_Payments + x$Potential_Reduction
)
# Full loss if the modelled population falls to zero.
zero <- model_payment_reduction(data.frame(Total_Payments = 100,
                                          Registered = 10, ONS = 0))
stopifnot(zero$Potential_Reduction == 100, zero$Remaining_Payments == 0)
# Use the unrounded rate in calculations, even when display rounds it.
fractional <- model_payment_reduction(data.frame(Total_Payments = 100,
                                                Registered = 3, ONS = 2))
stopifnot(abs(fractional$Potential_Reduction - 100 / 3) < 1e-10)
must_fail <- function(data, pattern) {
  err <- tryCatch(model_payment_reduction(data), error = identity)
  stopifnot(inherits(err, "error"), grepl(pattern, conditionMessage(err)))
}
must_fail(data.frame(Total_Payments = 100, Registered = 0, ONS = 2), "positive")
must_fail(data.frame(Total_Payments = NA_real_, Registered = 10, ONS = 2), "missing")
must_fail(data.frame(Total_Payments = -100, Registered = 10, ONS = 2), "negative")
cat("Payment reduction checks passed.\n")
