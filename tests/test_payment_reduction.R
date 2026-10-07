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
  abs(x$Loss_Per_ONS_Resident[1] - 165000 / 9000) < 1e-10,
  x$Loss_Per_Registered_Patient == c(16.5, 0, 0, 0),
  x$Total_Payments == x$Remaining_Payments + x$Potential_Reduction
)
# Full loss if the modelled population falls to zero.
zero <- model_payment_reduction(data.frame(Total_Payments = 100,
                                          Registered = 10, ONS = 0))
stopifnot(zero$Potential_Reduction == 100, zero$Remaining_Payments == 0)
stopifnot(is.na(zero$Loss_Per_ONS_Resident), zero$Loss_Per_Registered_Patient == 10)
# Population-normalised loss remains equal when every input is scaled equally.
scaled <- model_payment_reduction(example * 10)
stopifnot(all.equal(x$Loss_Per_ONS_Resident, scaled$Loss_Per_ONS_Resident),
          all.equal(x$Loss_Per_Registered_Patient, scaled$Loss_Per_Registered_Patient))
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
