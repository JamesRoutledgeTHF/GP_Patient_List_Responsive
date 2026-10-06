# Illustrative loss-only scenario: each removed registration carries the
# geography's observed average payment per registered patient with it.
model_payment_reduction <- function(data) {
  required <- c("Total_Payments", "Registered", "ONS")
  if (!all(required %in% names(data)) || nrow(data) == 0L) {
    stop("Payment reduction requires payments and both population totals.")
  }
  for (field in required) {
    values <- data[[field]]
    if (!is.numeric(values) || any(!is.finite(values)) || any(values < 0)) {
      stop("Payment reduction contains missing, non-finite or negative ", field, ".")
    }
  }
  if (any(data$Registered <= 0)) stop("Registered populations must be positive.")
  data$Payment_Per_Registered <- data$Total_Payments / data$Registered
  data$Registrations_Removed <- pmax(data$Registered - data$ONS, 0)
  data$Potential_Reduction <- pmin(data$Total_Payments,
    data$Registrations_Removed * data$Payment_Per_Registered)
  data$Remaining_Payments <- data$Total_Payments - data$Potential_Reduction
  data$Reduction_Pct <- ifelse(data$Total_Payments > 0,
    100 * data$Potential_Reduction / data$Total_Payments, 0)
  data
}

# Keep each geography's full observed payment total in both denominators.
model_fixed_total_payment_rates <- function(data) {
  required <- c("Total_Payments", "Registered", "ONS")
  if (!all(required %in% names(data)) || nrow(data) == 0L) {
    stop("Fixed-total payment rates require payments and both population totals.")
  }
  for (field in required) {
    values <- data[[field]]
    if (!is.numeric(values) || any(!is.finite(values)) || any(values < 0)) {
      stop("Fixed-total payment rates contain missing, non-finite or negative ", field, ".")
    }
  }
  if (any(data$Registered <= 0)) stop("Registered populations must be positive.")
  data$Payment_Per_Registered <- data$Total_Payments / data$Registered
  data$Payment_Per_ONS <- ifelse(data$ONS > 0, data$Total_Payments / data$ONS, NA_real_)
  data$Rate_Change <- data$Payment_Per_ONS - data$Payment_Per_Registered
  data$Rate_Change_Pct <- ifelse(data$Payment_Per_Registered > 0,
    100 * data$Rate_Change / data$Payment_Per_Registered, NA_real_)
  data
}
