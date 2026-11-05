source("18_Export_Chart_Data.R")
folder <- tempfile("chart-csv-test-")
dir.create(folder)
exporter <- new_chart_csv_exporter(folder)
input <- data.frame(ICB = c("Quoted, area", "Other area"),
  Period = as.Date(c("2013-07-01", "2024-07-01")),
  Value = c(123.456789012345, NA_real_),
  Source = factor(c("Registered patients", "ONS residents")))
exporter$write("first-chart", input, "Practice-level registrations",
  inputs = "Payments held fixed", reference_date = as.Date("2024-07-01"))
saved <- utils::read.csv(file.path(folder, "first-chart.csv"),
  stringsAsFactors = FALSE, check.names = FALSE)
stopifnot(nrow(saved) == 2L, saved$ICB[1] == input$ICB[1],
  max(abs(saved$Value[1] - input$Value[1])) < 1e-10,
  is.na(saved$Value[2]), identical(saved$Period, as.character(input$Period)),
  identical(saved$Source, as.character(input$Source)),
  all(saved$Export_Registration_Source == "Practice-level registrations"))
exporter$write("second-chart", input[FALSE, ], "LSOA-level registrations")
manifest <- exporter$finish(c("first-chart", "second-chart"))
stopifnot(nrow(manifest) == 2L, identical(manifest$Rows, c(2L, 0L)),
  file.exists(file.path(folder, "manifest.csv")),
  nrow(utils::read.csv(file.path(folder, "second-chart.csv"))) == 0L)
must_fail <- function(expr) {
  error <- tryCatch(force(expr), error = identity)
  stopifnot(inherits(error, "error"))
}
must_fail(exporter$write("first-chart", input, "Duplicate"))
must_fail(exporter$write("../outside", input, "Invalid path"))
must_fail(exporter$finish("first-chart"))
must_fail(exporter$write("list-column", data.frame(x = I(list(1, 2))), "Invalid data"))
# A later complete render removes only the stale files from its prior manifest.
utils::write.csv(data.frame(User = 1), file.path(folder, "unrelated.csv"), row.names = FALSE)
next_exporter <- new_chart_csv_exporter(folder)
next_exporter$write("first-chart", input, "Practice-level registrations")
next_exporter$finish("first-chart")
stopifnot(!file.exists(file.path(folder, "second-chart.csv")),
  file.exists(file.path(folder, "unrelated.csv")))
bad <- input
bad$Value <- c(Inf, NaN)
next_exporter$write("undefined-chart", bad, "Practice-level registrations")
undefined <- utils::read.csv(file.path(folder, "undefined-chart.csv"))
stopifnot(all(is.na(undefined$Value)))
unlink(folder, recursive = TRUE)
cat("Chart CSV export checks passed.\n")
