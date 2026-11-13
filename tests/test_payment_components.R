source("20_Select_Payment_Components.R")
source("13_Model_Payment_Reduction.R")

current <- as.Date("2025-03-31")
finance <- data.frame(
  Practice_Code = "A",
  Effective_Snapshot_Date = c(rep(current, 7), as.Date("2024-03-31")),
  Metric = c("Global Sum", "MPIG Correction factor", "Balance of PMS Expenditure",
    "Out Of Area in Hours Urgent Care", " GP  Extended Hours Access ",
    "PCN Participation", "Total NHS Payments to General Practice Minus Deductions",
    "Global Sum"),
  Metric_Value = c(1000, 10, 500, -30, 20, 99000, 999000, 888000))
selected <- select_payment_components(finance)
stopifnot(identical(selected$snapshot_date, current), nrow(selected$rows) == 5L,
  setequal(selected$rows$Component, names(selected_payment_component_names)),
  sum(selected$rows$Amount) == 1500,
  selected$rows$Amount[selected$rows$Component == "Out_of_Area_in_Hours_Urgent_Care"] == -30)

# A geography with no published component payments still receives the list-based addition.
local <- data.frame(Registered = c(100, 50), ONS = c(90, 60),
  Global_Sum = c(1000, 0), MPIG_Correction_Factor = c(10, 0),
  Balance_of_PMS_Expenditure = c(500, 0),
  Out_of_Area_in_Hours_Urgent_Care = c(-30, 0), GP_Extended_Hours_Access = c(20, 0))
local <- add_pcn_participation(local)
stopifnot(all(local$Selected_Published_Payments == c(1500, 0)),
  isTRUE(all.equal(local$PCN_Participation, c(4157.8, 2078.9))),
  isTRUE(all.equal(local$Total_Payments, c(5657.8, 2078.9))))
inputs <- c("Registered", "ONS", names(selected_payment_component_names))
england <- add_pcn_participation(as.data.frame(lapply(local[inputs], sum)))
stopifnot(isTRUE(all.equal(england$Total_Payments, sum(local$Total_Payments))))
fixed <- model_fixed_total_payment_rates(local)
loss <- model_payment_reduction(local)
stopifnot(isTRUE(all.equal(fixed$Payment_Per_Registered[1], 5657.8 / 100)),
  isTRUE(all.equal(fixed$Payment_Per_ONS[1], 5657.8 / 90)),
  isTRUE(all.equal(loss$Potential_Reduction, c(565.78, 0))),
  identical(fixed$PCN_Participation, local$PCN_Participation))

must_fail <- function(expr, pattern) {
  err <- tryCatch(force(expr), error = identity)
  stopifnot(inherits(err, "error"), grepl(pattern, conditionMessage(err)))
}
must_fail(select_payment_components(finance[-2, ]), "MPIG Correction Factor")
invalid <- finance
invalid$Metric_Value[1] <- NA_real_
must_fail(select_payment_components(invalid), "invalid amounts")
must_fail(add_pcn_participation(local, -1), "nonnegative")

# The full published aggregate is independently selected at the same snapshot.
full <- select_total_payments(finance, selected$snapshot_date)
stopifnot(nrow(full) == 1L, full$Total_Payments == 999000)
full_inputs <- data.frame(Total_Payments = sum(full$Total_Payments),
  Registered = 100, ONS = 90)
full_fixed <- model_fixed_total_payment_rates(full_inputs)
stopifnot(full_fixed$Payment_Per_Registered == 9990,
  full_fixed$Payment_Per_ONS == 11100,
  full_fixed$Rate_Change == 1110,
  !("PCN_Participation" %in% names(full_fixed)),
  isTRUE(all.equal(local$Total_Payments[1], 5657.8)),
  isTRUE(all.equal(loss$Potential_Reduction[1], 565.78)))
# An unavailable total at the selected snapshot must not use an older year.
older_total <- finance
older_total$Effective_Snapshot_Date[older_total$Metric ==
  "Total NHS Payments to General Practice Minus Deductions"] <- as.Date("2024-03-31")
must_fail(select_total_payments(older_total, selected$snapshot_date), "missing")
invalid_total <- finance
invalid_total$Metric_Value[invalid_total$Metric ==
  "Total NHS Payments to General Practice Minus Deductions"] <- NA_real_
must_fail(select_total_payments(invalid_total, selected$snapshot_date), "invalid amounts")

cat("Separate payment bases and PCN Participation checks passed.\n")
