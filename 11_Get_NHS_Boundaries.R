# Download and cache generalised NHS boundary polygon coordinates.
# This intentionally avoids an sf dependency so the report is portable.

arcgis_boundary_polygons <- function(
    service_url,
    code_field,
    name_field,
    cache_file
) {
  if (file.exists(cache_file)) {
    return(readRDS(cache_file))
  }

  query_url <- paste0(
    service_url,
    "/0/query?where=1%3D1&outFields=*",
    "&returnGeometry=true&outSR=4326&f=geojson"
  )

  response <- httr::GET(query_url)
  httr::stop_for_status(response)

  payload <- jsonlite::fromJSON(
    httr::content(response, as = "text", encoding = "UTF-8"),
    simplifyVector = FALSE
  )

  rows <- lapply(seq_along(payload$features), function(feature_index) {
    feature <- payload$features[[feature_index]]
    geometry <- feature$geometry

    polygons <- if (identical(geometry$type, "Polygon")) {
      list(geometry$coordinates)
    } else if (identical(geometry$type, "MultiPolygon")) {
      geometry$coordinates
    } else {
      stop("Unsupported ArcGIS geometry type: ", geometry$type)
    }

    polygon_rows <- lapply(seq_along(polygons), function(polygon_index) {
      rings <- polygons[[polygon_index]]

      ring_rows <- lapply(seq_along(rings), function(ring_index) {
        coordinates <- do.call(rbind, rings[[ring_index]])

        tibble::tibble(
          Boundary_Code = feature$properties[[code_field]],
          Boundary_Name = feature$properties[[name_field]],
          Longitude = as.numeric(coordinates[, 1]),
          Latitude = as.numeric(coordinates[, 2]),
          Polygon_Group = paste(
            feature_index,
            polygon_index,
            ring_index,
            sep = "-"
          )
        )
      })

      dplyr::bind_rows(ring_rows)
    })

    dplyr::bind_rows(polygon_rows)
  })

  boundary <- dplyr::bind_rows(rows)
  saveRDS(boundary, cache_file)
  boundary
}

nhser_boundaries <- arcgis_boundary_polygons(
  paste0(
    "https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/",
    "NHS_England_Regions_January_2024_EN_BGC/FeatureServer"
  ),
  "NHSER24CD",
  "NHSER24NM",
  "NHSER24_boundary_polygons.rds"
)

icb_boundaries <- arcgis_boundary_polygons(
  paste0(
    "https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/",
    "Integrated_Care_Boards_April_2026_Boundaries_EN_BGC/FeatureServer"
  ),
  "ICB26CD",
  "ICB26NM",
  "ICB26_boundary_polygons.rds"
)
