# One CSV per labelled chart, using the numeric data supplied to ggplot.
# A manifest is committed only after every expected figure has exported.
new_chart_csv_exporter <- function(output_dir) {
  if (length(output_dir) != 1L || is.na(output_dir) || !nzchar(output_dir)) {
    stop("Provide a chart-data output folder.")
  }
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(output_dir)) stop("Cannot create chart-data folder: ", output_dir)
  records <- list()
  write_csv <- function(data, file) {
    temporary <- tempfile(pattern = "chart-", tmpdir = output_dir, fileext = ".tmp")
    on.exit(unlink(temporary), add = TRUE)
    utils::write.csv(data, temporary, row.names = FALSE, na = "", fileEncoding = "UTF-8")
    if (!file.copy(temporary, file, overwrite = TRUE)) {
      stop("Could not save chart CSV: ", file)
    }
  }
  write_chart <- function(chart_id, data, registration_source,
    ons_source = "English LSOA population estimates", inputs = "",
    reference_date = as.Date(NA), payment_date = as.Date(NA), measure = "") {
    if (length(chart_id) != 1L || is.na(chart_id) ||
        !grepl("^[a-z][a-z0-9-]*$", chart_id)) stop("Invalid chart export ID.")
    if (chart_id %in% names(records)) stop("Duplicate chart export ID: ", chart_id)
    if (!is.data.frame(data) || ncol(data) == 0L || anyDuplicated(names(data))) {
      stop("Chart CSV requires a data frame with unique column names: ", chart_id)
    }
    if (any(vapply(data, is.list, logical(1)))) {
      stop("Remove geometry/list columns before exporting chart ", chart_id, ".")
    }
    data <- as.data.frame(data)
    for (column in names(data)) {
      value <- data[[column]]
      if (inherits(value, "Date")) {
        data[[column]] <- as.character(value)
      } else if (inherits(value, "POSIXt")) {
        data[[column]] <- format(value, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
      } else if (is.factor(value)) {
        data[[column]] <- as.character(value)
      } else if (is.numeric(value)) {
        data[[column]][!is.finite(value)] <- NA
      }
    }
    metadata <- list(Export_Chart_ID = chart_id,
      Export_Registration_Source = registration_source, Export_ONS_Source = ons_source,
      Export_Inputs = inputs, Export_Report_Reference_Date = as.character(reference_date),
      Export_Payment_Snapshot_Date = as.character(payment_date), Export_Measure = measure)
    if (length(intersect(names(metadata), names(data)))) stop("Reserved CSV metadata column.")
    for (name in names(metadata)) {
      if (length(metadata[[name]]) != 1L) stop("CSV metadata must contain scalar values.")
    }
    metadata_rows <- as.data.frame(lapply(metadata, rep, length.out = nrow(data)),
                                  stringsAsFactors = FALSE)
    filename <- paste0(chart_id, ".csv")
    write_csv(cbind(metadata_rows, data), file.path(output_dir, filename))
    records[[chart_id]] <<- data.frame(Chart_ID = chart_id, File = filename,
      Rows = nrow(data), Registration_Source = registration_source,
      ONS_Source = ons_source, Inputs = inputs, Measure = measure,
      Report_Reference_Date = as.character(reference_date),
      Payment_Snapshot_Date = as.character(payment_date), stringsAsFactors = FALSE)
    invisible(filename)
  }
  finish <- function(expected_chart_ids) {
    if (!length(expected_chart_ids) || anyDuplicated(expected_chart_ids) ||
        !setequal(expected_chart_ids, names(records))) {
      stop("Chart CSV coverage does not match the report's figures.")
    }
    manifest_file <- file.path(output_dir, "manifest.csv")
    previous <- if (file.exists(manifest_file)) {
      tryCatch(utils::read.csv(manifest_file, stringsAsFactors = FALSE),
               error = function(e) NULL)
    } else NULL
    manifest <- do.call(rbind, records[expected_chart_ids])
    rownames(manifest) <- NULL
    write_csv(manifest, manifest_file)
    # Remove only old exports named by the previous generated manifest.
    if (!is.null(previous) && all(c("Chart_ID", "File") %in% names(previous))) {
      valid <- !is.na(previous$Chart_ID) & !is.na(previous$File) &
        grepl("^[a-z][a-z0-9-]*$", previous$Chart_ID) &
        previous$File == paste0(previous$Chart_ID, ".csv")
      stale <- setdiff(previous$File[valid], manifest$File)
      if (length(stale)) unlink(file.path(output_dir, stale))
    }
    invisible(manifest)
  }
  list(write = write_chart, finish = finish)
}
