# Published practice payment headings; use only these five leaf components.
# https://digital.nhs.uk/data-and-information/publications/statistical/nhs-payments-to-general-practice/england-2024-25
selected_payment_component_names <- c(
  Global_Sum = "Global Sum",
  MPIG_Correction_Factor = "MPIG Correction Factor",
  Balance_of_PMS_Expenditure = "Balance of PMS Expenditure",
  Out_of_Area_in_Hours_Urgent_Care = "Out of Area in Hours Urgent Care",
  GP_Extended_Hours_Access = "GP Extended Hours Access"
)

pcn_participation_rate <- 41.578

select_payment_components <- function(finance) {
  required <- c("Practice_Code", "Effective_Snapshot_Date", "Metric", "Metric_Value")
  if (!all(required %in% names(finance)) || !nrow(finance)) {
    stop("Payment components require practice, date, metric and amount fields.")
  }
  dates <- as.Date(finance$Effective_Snapshot_Date)
  if (anyNA(dates)) stop("Payment data contain missing snapshot dates.")
  snapshot <- max(dates)
  current <- finance[dates == snapshot, required, drop = FALSE]
  normalise <- function(x) tolower(trimws(gsub("[[:space:]]+", " ", as.character(x))))
  component <- match(normalise(current$Metric), normalise(selected_payment_component_names))
  missing <- setdiff(seq_along(selected_payment_component_names), component)
  if (length(missing)) {
    stop("Payment snapshot ", snapshot, " is missing required components: ",
         paste(selected_payment_component_names[missing], collapse = ", "))
  }
  included <- !is.na(component)
  values <- suppressWarnings(as.numeric(as.character(current$Metric_Value[included])))
  if (any(!is.finite(values))) {
    stop("Selected payment components contain missing or invalid amounts.")
  }
  # Preserve signed adjustments. Published totals and recorded PCN are excluded.
  list(snapshot_date = snapshot, rows = data.frame(
    Practice_Code = trimws(as.character(current$Practice_Code[included])),
    Component = names(selected_payment_component_names)[component[included]],
    Amount = values, stringsAsFactors = FALSE))
}

add_pcn_participation <- function(data, rate = pcn_participation_rate) {
  components <- names(selected_payment_component_names)
  if (!all(c("Registered", components) %in% names(data)) || !nrow(data)) {
    stop("The payment model needs registered counts and all five component totals.")
  }
  if (!is.numeric(rate) || length(rate) != 1L || !is.finite(rate) || rate < 0) {
    stop("PCN Participation rate must be a finite nonnegative amount.")
  }
  for (field in c("Registered", components)) {
    if (!is.numeric(data[[field]]) || any(!is.finite(data[[field]]))) {
      stop("Invalid payment-model input: ", field)
    }
  }
  if (any(data$Registered < 0)) stop("Registered counts cannot be negative.")
  data$Selected_Published_Payments <- rowSums(data[components])
  data$PCN_Participation_Per_Registered <- rate
  data$PCN_Participation <- data$Registered * rate
  data$Total_Payments <- data$Selected_Published_Payments + data$PCN_Participation
  data
}

# Read the published aggregate for the fixed-total scenario at the SAME snapshot.
# No selected components or custom PCN amounts are added to this field.
select_total_payments <- function(finance, snapshot_date) {
  required <- c("Practice_Code", "Effective_Snapshot_Date", "Metric", "Metric_Value")
  if (!all(required %in% names(finance))) stop("Missing total-payment fields.")
  snapshot_date <- as.Date(snapshot_date)
  dates <- as.Date(finance$Effective_Snapshot_Date)
  if (length(snapshot_date) != 1L || is.na(snapshot_date) || anyNA(dates)) {
    stop("Invalid total-payment snapshot dates.")
  }
  normalise <- function(x) tolower(trimws(gsub("[[:space:]]+", " ", as.character(x))))
  selected <- dates == snapshot_date &
    !is.na(finance$Metric) &
    normalise(finance$Metric) ==
      normalise("Total NHS Payments to General Practice Minus Deductions")
  if (!any(selected)) stop("Published total payments minus deductions are missing at the selected snapshot.")
  values <- suppressWarnings(as.numeric(as.character(finance$Metric_Value[selected])))
  if (any(!is.finite(values))) stop("Published total payments contain invalid amounts.")
  data.frame(Practice_Code = trimws(as.character(finance$Practice_Code[selected])),
    Total_Payments = values, stringsAsFactors = FALSE)
}
