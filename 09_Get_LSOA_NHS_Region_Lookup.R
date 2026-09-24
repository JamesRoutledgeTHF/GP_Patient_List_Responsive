# Load official ONS April 2024 geography for the focused report.
#
# LSOA-level population analyses use the ONS LSOA21 -> SICBL24 -> ICB24
# lookup. NHS England region is added from the official ONS 2024
# ICB24 -> NHSER24 relationship so all LSOA-based geography is on a
# consistent April 2024 basis.

nhser_cache <- "LSOA21_to_SICBL24_ICB24_NHSER24.csv"

required_lookup_fields <- c(
  "LSOA21CD",
  "SICBL24CD", "SICBL24NM",
  "ICB24CD", "ICB24NM",
  "NHSER24CD", "NHSER24NM"
)

fetch_arcgis_table <- function(
    endpoint,
    out_fields,
    order_field,
    distinct = FALSE,
    page_size = 1000L
) {
  pages <- list()
  offset <- 0L

  repeat {
    query_args <- list(
      where = "1=1",
      outFields = paste(out_fields, collapse = ","),
      returnGeometry = "false",
      resultOffset = offset,
      resultRecordCount = page_size,
      orderByFields = order_field,
      f = "json"
    )

    if (isTRUE(distinct)) {
      query_args$returnDistinctValues <- "true"
    }

    response <- httr::GET(endpoint, query = query_args)
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
      break
    }

    pages[[length(pages) + 1L]] <- page

    if (!isTRUE(payload$exceededTransferLimit)) {
      break
    }

    offset <- offset + nrow(page)
  }

  dplyr::bind_rows(pages) %>%
    dplyr::mutate(dplyr::across(dplyr::everything(), as.character))
}

fetch_nhser_lookup <- function() {
  lsoa_endpoint <- paste0(
    "https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/",
    "LSOA21_SICBL24_ICB24_CAL24_LAD24_EN_LU/FeatureServer/0/query"
  )

  region_endpoint <- paste0(
    "https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/",
    "OA21_SICBL24_ICB24_NHSER24_EN_LU/FeatureServer/0/query"
  )

  lsoa_to_icb <- fetch_arcgis_table(
    endpoint = lsoa_endpoint,
    out_fields = c(
      "LSOA21CD",
      "SICBL24CD", "SICBL24NM",
      "ICB24CD", "ICB24NM"
    ),
    order_field = "LSOA21CD"
  ) %>%
    dplyr::distinct(LSOA21CD, .keep_all = TRUE)

  icb_to_region <- fetch_arcgis_table(
    endpoint = region_endpoint,
    out_fields = c(
      "ICB24CD", "ICB24NM",
      "NHSER24CD", "NHSER24NM"
    ),
    order_field = "ICB24CD",
    distinct = TRUE
  ) %>%
    dplyr::distinct(
      ICB24CD,
      ICB24NM,
      NHSER24CD,
      NHSER24NM
    )

  lookup <- lsoa_to_icb %>%
    dplyr::left_join(
      icb_to_region %>%
        dplyr::select(
          ICB24CD,
          NHSER24CD,
          NHSER24NM
        ) %>%
        dplyr::distinct(),
      by = "ICB24CD"
    )

  missing_fields <- setdiff(required_lookup_fields, names(lookup))
  if (length(missing_fields) > 0) {
    stop(
      "The ONS April 2024 geography lookup is missing required fields: ",
      paste(missing_fields, collapse = ", ")
    )
  }

  lookup %>%
    dplyr::select(dplyr::all_of(required_lookup_fields)) %>%
    dplyr::distinct(LSOA21CD, .keep_all = TRUE)
}

cache_is_valid <- FALSE

if (file.exists(nhser_cache)) {
  cached_lookup <- readr::read_csv(
    nhser_cache,
    show_col_types = FALSE,
    col_types = readr::cols(.default = readr::col_character())
  )

  cache_is_valid <- all(required_lookup_fields %in% names(cached_lookup))
}

if (cache_is_valid) {
  nhser_lookup <- cached_lookup %>%
    dplyr::select(dplyr::all_of(required_lookup_fields)) %>%
    dplyr::distinct(LSOA21CD, .keep_all = TRUE)
} else {
  nhser_lookup <- fetch_nhser_lookup()
  readr::write_csv(nhser_lookup, nhser_cache)
}

if (anyDuplicated(nhser_lookup$LSOA21CD)) {
  stop("The ONS April 2024 LSOA lookup contains duplicate LSOA21CD values.")
}

if (any(is.na(nhser_lookup$ICB24CD)) || any(is.na(nhser_lookup$ICB24NM))) {
  warning("Some LSOAs do not have an April 2024 ICB assignment.")
}

if (any(is.na(nhser_lookup$NHSER24CD)) || any(is.na(nhser_lookup$NHSER24NM))) {
  warning("Some April 2024 ICBs do not have an NHS England region assignment.")
}
