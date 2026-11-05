# ONS April 2026 ICB boundaries, super-generalised and coast-clipped (200 m).
# Source: https://www.data.gov.uk/dataset/3735c4be-8ae8-43a3-8a7c-40fec660e6e5/integrated-care-boards-april-2026-boundaries-en-bsc
# This layer uses the same 36 ICB codes as the report's April 2026 LSOA lookup.
load_icb_map_boundaries <- function(expected_codes,
  cache_file = "data/ICB_April2026_BSC.geojson") {
  expected_codes <- unique(as.character(expected_codes))
  if (length(expected_codes) != 36L || anyNA(expected_codes) ||
      any(!nzchar(expected_codes))) {
    stop("The ICB map requires all 36 April 2026 ICB codes.")
  }
  is_valid <- function(boundaries) {
    inherits(boundaries, "sf") &&
      all(c("ICB26CD", "ICB26NM") %in% names(boundaries)) &&
      nrow(boundaries) == length(expected_codes) &&
      !anyNA(boundaries$ICB26CD) &&
      !anyDuplicated(boundaries$ICB26CD) &&
      setequal(boundaries$ICB26CD, expected_codes) &&
      !is.na(sf::st_crs(boundaries)) &&
      !any(sf::st_is_empty(boundaries))
  }
  if (file.exists(cache_file)) {
    cached <- tryCatch(sf::st_read(cache_file, quiet = TRUE), error = function(e) NULL)
    if (is_valid(cached)) return(sf::st_transform(cached, 27700))
  }
  endpoint <- paste0(
    "https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/",
    "Integrated_Care_Boards_April_2026_Boundaries_EN_BSC/FeatureServer/0/query")
  response <- httr::GET(endpoint, httr::timeout(120), query = list(
    where = "1=1", outFields = "ICB26CD,ICB26NM", returnGeometry = "true",
    outSR = 4326, orderByFields = "ICB26CD", resultRecordCount = 100, f = "geojson"))
  httr::stop_for_status(response)
  body <- httr::content(response, as = "text", encoding = "UTF-8")
  payload <- jsonlite::fromJSON(body, simplifyVector = FALSE)
  if (!is.null(payload$error) || !identical(payload$type, "FeatureCollection") ||
      isTRUE(payload$exceededTransferLimit)) {
    stop("ONS did not return a complete April 2026 ICB boundary collection.")
  }
  temporary_file <- tempfile(fileext = ".geojson")
  on.exit(unlink(temporary_file), add = TRUE)
  writeLines(body, temporary_file, useBytes = TRUE)
  boundaries <- sf::st_read(temporary_file, quiet = TRUE)
  if (!is_valid(boundaries)) {
    stop("ONS ICB boundary codes do not match the report's April 2026 geography.")
  }
  dir.create(dirname(cache_file), recursive = TRUE, showWarnings = FALSE)
  if (!file.copy(temporary_file, cache_file, overwrite = TRUE)) {
    warning("Could not cache ICB boundaries; using the validated downloaded layer.")
  }
  sf::st_transform(boundaries, 27700)
}
