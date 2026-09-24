# Load the official ONS LSOA 2021 -> Sub ICB -> ICB -> NHS England region lookup.
# A local CSV cache avoids downloading the same lookup on every render.

nhser_cache <- "LSOA21_to_SICBL26_ICB26_NHSER26.csv"

required_lookup_fields <- c(
  "LSOA21CD",
  "SICBL26CD", "SICBL26NM",
  "ICB26CD", "ICB26NM",
  "NHSER26CD", "NHSER26NM"
)

fetch_nhser_lookup <- function() {
  endpoint <- paste0(
    "https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/",
    "LSOA21_SICBL26_ICB26_NHSER26_LAD26/FeatureServer/0/query"
  )

  pages <- list()
  offset <- 0L
  page_size <- 2000L

  repeat {
    response <- httr::GET(
      endpoint,
      query = list(
        where = "1=1",
        outFields = paste(required_lookup_fields, collapse = ","),
        returnGeometry = "false",
        resultOffset = offset,
        resultRecordCount = page_size,
        orderByFields = "LSOA21CD",
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
      break
    }

    pages[[length(pages) + 1L]] <- page

    if (!isTRUE(payload$exceededTransferLimit)) {
      break
    }

    offset <- offset + nrow(page)
  }

  lookup <- dplyr::bind_rows(pages)

  missing_fields <- setdiff(required_lookup_fields, names(lookup))
  if (length(missing_fields) > 0) {
    stop(
      "The ONS geography service did not return required fields: ",
      paste(missing_fields, collapse = ", ")
    )
  }

  lookup %>%
    dplyr::select(dplyr::all_of(required_lookup_fields)) %>%
    dplyr::mutate(dplyr::across(dplyr::everything(), as.character)) %>%
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
  stop("The ONS LSOA geography lookup contains duplicate LSOA21CD values.")
}

if (any(is.na(nhser_lookup$ICB26CD)) || any(is.na(nhser_lookup$ICB26NM))) {
  warning("Some LSOAs do not have an ICB26 assignment in the ONS lookup.")
}
