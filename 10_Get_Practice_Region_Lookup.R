# Build a one-row-per-practice NHS England region lookup from the payments file.

practice_region_lookup <- readr::read_csv(
  "payments2425.csv",
  show_col_types = FALSE,
  col_types = readr::cols(.default = readr::col_character())
) |>
  dplyr::transmute(
    Practice_Code = `Practice Code`,
    NHS_Region = dplyr::recode(
      `NHS England (Region) Name`,
      "EAST OF ENGLAND COMMISSIONING REGION" = "East of England",
      "LONDON COMMISSIONING REGION" = "London",
      "MIDLANDS COMMISSIONING REGION" = "Midlands",
      "NORTH EAST AND YORKSHIRE COMMISSIONING REGION" =
        "North East and Yorkshire",
      "NORTH WEST COMMISSIONING REGION" = "North West",
      "SOUTH EAST COMMISSIONING REGION" = "South East",
      "SOUTH WEST COMMISSIONING REGION" = "South West",
      .default = NA_character_
    )
  ) |>
  dplyr::filter(!is.na(Practice_Code), !is.na(NHS_Region)) |>
  dplyr::distinct(Practice_Code, .keep_all = TRUE)
