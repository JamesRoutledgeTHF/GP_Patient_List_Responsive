# Run from the repository root: Rscript tests/test_fixed_total_payment_rates.R
source("13_Model_Payment_Reduction.R")
example <- data.frame(
  Geography = c("Lower ONS", "Equal", "Higher ONS", "No payments", "No ONS"),
  Total_Payments = c(1650000, 16500, 16500, 0, 100),
  Registered = c(10000, 100, 100, 100, 10),
  ONS = c(9000, 100, 120, 80, 0)
)
x <- model_fixed_total_payment_rates(example)
stopifnot(
  identical(x$Total_Payments, example$Total_Payments),
  identical(x$Geography, example$Geography),
  x$Payment_Per_Registered[1] == 165,
  abs(x$Payment_Per_ONS[1] - 183.333333333333) < 1e-10,
  abs(x$Rate_Change_Pct[1] - 100 / 9) < 1e-10,
  x$Rate_Change[2] == 0,
  x$Payment_Per_ONS[3] == 137.5,
  x$Rate_Change[3] == -27.5,
  x$Payment_Per_ONS[4] == 0, is.na(x$Rate_Change_Pct[4]),
  is.na(x$Payment_Per_ONS[5]), is.na(x$Rate_Change[5])
)
# The whole payment pot is retained; it must not use Remaining_Payments.
loss <- model_payment_reduction(example)
fixed_after_loss <- model_fixed_total_payment_rates(loss)
stopifnot(
  loss$Remaining_Payments[1] == 1485000,
  fixed_after_loss$Payment_Per_ONS[1] == x$Payment_Per_ONS[1],
  abs(x$Payment_Per_Registered[1] * example$Registered[1] - 1650000) < 1e-8,
  abs(x$Payment_Per_ONS[1] * example$ONS[1] - 1650000) < 1e-8
)
fractional <- model_fixed_total_payment_rates(data.frame(
  Total_Payments = 100, Registered = 3, ONS = 2
))
stopifnot(fractional$Payment_Per_Registered == 100 / 3,
          fractional$Payment_Per_ONS == 50)
must_fail <- function(data) {
  err <- tryCatch(model_fixed_total_payment_rates(data), error = identity)
  stopifnot(inherits(err, "error"))
}
must_fail(data.frame(Total_Payments = 100, Registered = 0, ONS = 2))
must_fail(data.frame(Total_Payments = NA_real_, Registered = 10, ONS = 2))
must_fail(data.frame(Total_Payments = -100, Registered = 10, ONS = 2))
must_fail(data.frame(Total_Payments = 100, Registered = 10, ONS = -2))
cat("Fixed-total payment rate checks passed.\n")
