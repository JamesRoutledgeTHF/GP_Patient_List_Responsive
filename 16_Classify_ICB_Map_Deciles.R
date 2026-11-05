# Deciles of signed percentage difference: larger registration excess = higher.
# Identical values always share a group. Missing/nonfinite values are unclassified.
classify_icb_map_deciles <- function(values) {
  if (!is.numeric(values)) stop("ICB map percentages must be numeric.")
  available <- is.finite(values)
  if (!any(available)) stop("No finite ICB percentage differences are available to map.")
  thresholds <- as.numeric(stats::quantile(values[available],
    probs = seq(0.1, 0.9, by = 0.1), type = 7, names = FALSE))
  decile <- rep(NA_integer_, length(values))
  decile[available] <- vapply(values[available],
    function(value) 1L + sum(value > thresholds), integer(1))
  labels <- c("1 (Lowest difference)", as.character(2:9), "10 (Highest difference)")
  label <- rep("No comparable data", length(values))
  label[available] <- labels[decile[available]]
  counts <- tabulate(decile[available], nbins = 10L)
  group_min <- group_max <- rep(NA_real_, 10L)
  for (group in 1:10) {
    selected <- values[available & !is.na(decile) & decile == group]
    if (length(selected)) {
      group_min[group] <- min(selected)
      group_max[group] <- max(selected)
    }
  }
  list(decile = decile,
    label = factor(label, levels = c(labels, "No comparable data")),
    key = data.frame(Decile = 1:10, ICBs = counts,
      Minimum_Pct = group_min, Maximum_Pct = group_max),
    thresholds = thresholds)
}
