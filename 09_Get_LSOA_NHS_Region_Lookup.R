# Apply official ONS April 2026 geography to the original population snapshots.
# Source: https://www.data.gov.uk/dataset/1d16e489-1dc8-443e-9e1c-15de4f961c6d/lsoa-2021-to-sicbl-to-icb-to-nhser-to-lad-april-2026-lookup-in-en
# This changes geography only. It does not change the dates or source counts.

nhser_cache <- "LSOA21_to_SICBL26_ICB26_NHSER26.csv"

required_lookup_fields <- c(
  "LSOA21CD",
  "SICBL26CD", "SICBL26CDH", "SICBL26NM",
  "ICB26CD", "ICB26CDH", "ICB26NM",
  "NHSER26CD", "NHSER26NM"
)

fetch_arcgis_table <- function(endpoint, out_fields, order_field, page_size = 1000L) {
  pages <- list()
  offset <- 0L
  repeat {
    response <- httr::GET(
      endpoint,
      httr::timeout(60),
      query = list(
        where = "1=1",
        outFields = paste(out_fields, collapse = ","),
        returnGeometry = "false",
        resultOffset = offset,
        resultRecordCount = page_size,
        orderByFields = order_field,
        f = "json"
      )
    )
    httr::stop_for_status(response)
    payload <- jsonlite::fromJSON(
      httr::content(response, as = "text", encoding = "UTF-8"),
      simplifyDataFrame = TRUE
    )
    if (!is.null(payload$error)) {
      stop("ONS ArcGIS lookup failed: ", payload$error$message)
    }
    page <- payload$features$attributes
    if (is.null(page) || nrow(page) == 0) {
      if (isTRUE(payload$exceededTransferLimit)) {
        stop("ONS ArcGIS returned an empty page before completing the lookup.")
      }
      break
    }
    pages[[length(pages) + 1L]] <- page
    if (!isTRUE(payload$exceededTransferLimit)) break
    offset <- offset + nrow(page)
  }
  dplyr::bind_rows(pages) %>%
    dplyr::mutate(dplyr::across(dplyr::everything(), as.character))
}

lookup_is_valid <- function(lookup) {
  all(required_lookup_fields %in% names(lookup)) &&
    nrow(lookup) == 33755L &&
    !anyDuplicated(lookup$LSOA21CD) &&
    !anyNA(lookup[required_lookup_fields]) &&
    !any(as.matrix(lookup[required_lookup_fields]) == "") &&
    dplyr::n_distinct(lookup$ICB26CD) == 36L
}

fetch_nhser_lookup <- function() {
  endpoint <- paste0(
    "https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/",
    "LSOA21_SICBL26_ICB26_NHSER26_LAD26/FeatureServer/0/query"
  )
  lookup <- fetch_arcgis_table(endpoint, required_lookup_fields, "LSOA21CD")
  if (!lookup_is_valid(lookup)) {
    stop("The ONS April 2026 lookup is incomplete or has conflicting LSOA mappings.")
  }
  dplyr::select(lookup, dplyr::all_of(required_lookup_fields))
}

cache_is_valid <- FALSE
if (file.exists(nhser_cache)) {
  cached_lookup <- readr::read_csv(
    nhser_cache,
    show_col_types = FALSE,
    col_types = readr::cols(.default = readr::col_character())
  )
  cache_is_valid <- lookup_is_valid(cached_lookup)
}

if (cache_is_valid) {
  nhser_lookup <- dplyr::select(cached_lookup, dplyr::all_of(required_lookup_fields))
} else {
  nhser_lookup <- fetch_nhser_lookup()
  readr::write_csv(nhser_lookup, nhser_cache)
}
