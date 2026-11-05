# Difference maps retain both original rates, counts and the shared denominator.
# Missing ICBs/rates remain grey; classification uses signed differences.
prepare_icb_difference_map <- function(data, expected_codes, registered_column,
  ons_column, direction = c("registered-minus-ons", "ons-minus-registered")) {
  direction <- match.arg(direction)
  rate_columns <- c(registered_column, ons_column)
  if (!is.data.frame(data) || !"ICB_Key" %in% names(data) ||
      length(registered_column) != 1L || length(ons_column) != 1L ||
      !all(rate_columns %in% names(data))) stop("Invalid ICB difference map inputs.")
  if (anyNA(data$ICB_Key) || anyDuplicated(data$ICB_Key)) {
    stop("ICB difference map requires one row per ICB.")
  }
  expected_codes <- as.character(expected_codes)
  if (!length(expected_codes) || anyNA(expected_codes) ||
      anyDuplicated(expected_codes) || any(!nzchar(expected_codes)) ||
      any(!data$ICB_Key %in% expected_codes)) stop("ICB map geography mismatch.")
  if (!all(vapply(data[rate_columns], is.numeric, logical(1)))) {
    stop("ICB map rates must be numeric.")
  }
  for (column in rate_columns) {
    if (any(data[[column]] < 0, na.rm = TRUE)) stop("ICB map rates cannot be negative.")
  }
  rows <- merge(data.frame(ICB_Key = expected_codes, stringsAsFactors = FALSE),
                data, by = "ICB_Key", all.x = TRUE, sort = FALSE)
  rows$Map_Difference <- if (direction == "registered-minus-ons") {
    rows[[registered_column]] - rows[[ons_column]]
  } else rows[[ons_column]] - rows[[registered_column]]
  rows$Map_Difference[!is.finite(rows$Map_Difference)] <- NA_real_
  classification <- classify_icb_map_deciles(rows$Map_Difference)
  rows$Difference_Definition <- direction
  rows$Map_Decile <- classification$decile
  rows$Map_Decile_Label <- classification$label
  rows$Decile_Minimum_Difference <- classification$key$Minimum_Pct[rows$Map_Decile]
  rows$Decile_Maximum_Difference <- classification$key$Maximum_Pct[rows$Map_Decile]
  key <- classification$key
  names(key)[names(key) == "Minimum_Pct"] <- "Minimum_Difference"
  names(key)[names(key) == "Maximum_Pct"] <- "Maximum_Difference"
  list(data = rows, key = key)
}
