# Load the LSOA 2021 to NHS England region lookup used by the focused report.
# A local CSV cache avoids downloading the same lookup on every render.

nhser_cache <- "LSOA21_to_NHSER26.csv"

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
        outFields = "LSOA21CD,NHSER26CD,NHSER26NM",
        returnGeometry = "false",
        resultOffset = offset,
        resultRecordCount = page_size,
        orderByFields = "ObjectId",
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

  dplyr::bind_rows(pages) %>%
    dplyr::distinct(LSOA21CD, .keep_all = TRUE)
}

if (file.exists(nhser_cache)) {
  nhser_lookup <- readr::read_csv(
    nhser_cache,
    show_col_types = FALSE,
    col_types = readr::cols(.default = readr::col_character())
  )
} else {
  nhser_lookup <- fetch_nhser_lookup()
  readr::write_csv(nhser_lookup, nhser_cache)
}
