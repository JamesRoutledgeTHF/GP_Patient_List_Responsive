source("16_Classify_ICB_Map_Deciles.R")
# Ten distinct values should occupy the ten quantile groups in order.
x <- classify_icb_map_deciles(1:10)
stopifnot(identical(x$decile, 1:10), sum(x$key$ICBs) == 10L,
  all(x$key$ICBs == 1L), x$label[1] == "1 (Lowest difference)",
  x$label[10] == "10 (Highest difference)")
# Values exactly on repeated thresholds share the same lower group.
ties <- classify_icb_map_deciles(c(rep(2, 8), 5, 10))
stopifnot(length(unique(ties$decile[1:8])) == 1L,
  ties$decile[1] == 1L, ties$decile[10] == 10L,
  any(ties$key$ICBs == 0L), sum(ties$key$ICBs) == 10L)
# Higher signed differences rank higher, even when all values are negative.
negative <- classify_icb_map_deciles(-10:-1)
stopifnot(identical(negative$decile, 1:10))
# Missing/undefined percentages do not change the classification or thresholds.
missing <- classify_icb_map_deciles(c(1:10, NA_real_, Inf, -Inf, NaN))
stopifnot(identical(missing$decile[1:10], x$decile),
  all(is.na(missing$decile[11:14])),
  all(missing$label[11:14] == "No comparable data"),
  identical(missing$thresholds, x$thresholds))
equal <- classify_icb_map_deciles(rep(4.5, 36))
stopifnot(all(equal$decile == 1L), equal$key$ICBs[1] == 36L,
  sum(equal$key$ICBs[-1]) == 0L)
# Classification is independent of row order; tied observations never split.
values <- c(1:20, 4, 4, 9, 9)
order <- rev(seq_along(values))
original <- classify_icb_map_deciles(values)
permuted <- classify_icb_map_deciles(values[order])
stopifnot(identical(original$decile[order], permuted$decile),
  length(unique(original$decile[values == 4])) == 1L)
must_fail <- function(values) {
  error <- tryCatch(classify_icb_map_deciles(values), error = identity)
  stopifnot(inherits(error, "error"))
}
must_fail(c(NA_real_, Inf))
must_fail(numeric())
must_fail(c("1", "2"))
cat("ICB map decile checks passed.\n")
