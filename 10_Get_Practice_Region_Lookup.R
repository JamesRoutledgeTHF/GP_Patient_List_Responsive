# Build practice -> NHS England region and practice -> ICB26 lookups.
# The practice geography comes from payments2425.csv. The Sub ICB field is
# reconciled to the official ONS SICBL26 -> ICB26 lookup loaded by script 09.

required_objects <- c("nhser_lookup")
missing_objects <- required_objects[
  !vapply(required_objects, exists, logical(1), inherits = TRUE)
]

if (length(missing_objects) > 0) {
  stop(
    "10_Get_Practice_Region_Lookup.R requires: ",
    paste(missing_objects, collapse = ", ")
  )
}

payments_lookup_file <- "payments2425.csv"

if (!file.exists(payments_lookup_file)) {
  stop("Cannot find practice geography file: ", payments_lookup_file)
}

practice_geo_raw <- readr::read_csv(
  payments_lookup_file,
  show_col_types = FALSE,
  col_types = readr::cols(.default = readr::col_character()),
  name_repair = "minimal"
)

required_payment_fields <- c(
  "Practice Code",
  "NHS England (Region) Name",
  "Sub ICB Code",
  "Sub ICB Name"
)

missing_payment_fields <- setdiff(required_payment_fields, names(practice_geo_raw))
if (length(missing_payment_fields) > 0) {
  stop(
    "payments2425.csv is missing required geography fields: ",
    paste(missing_payment_fields, collapse = ", ")
  )
}

normalise_key <- function(x) {
  x <- toupper(trimws(as.character(x)))
  x <- gsub("\\s+", " ", x)
  x <- gsub("[^A-Z0-9 ]", "", x)
  trimws(x)
}

normalise_region_name <- function(x) {
  x <- normalise_key(x)
  x <- gsub("^NHS ENGLAND ", "", x)
  x <- gsub(" COMMISSIONING REGION$", "", x)
  x <- gsub(" REGION$", "", x)
  trimws(x)
}

normalise_icb_parent_name <- function(x) {
  x <- toupper(trimws(as.character(x)))
  x <- gsub("\\s+-\\s+[A-Z0-9]+$", "", x)
  x <- gsub("^NHS\\s+", "", x)
  x <- gsub("\\s+INTEGRATED CARE BOARD$", "", x)
  x <- gsub("\\s+ICB$", "", x)
  x <- gsub("[^A-Z0-9 ]", "", x)
  x <- gsub("\\s+", " ", x)
  trimws(x)
}

sicbl_to_icb <- nhser_lookup %>%
  dplyr::filter(!is.na(SICBL26NM), SICBL26NM != "") %>%
  dplyr::transmute(
    SICBL_Name_Key = normalise_key(SICBL26NM),
    ICB26CD,
    ICB26NM,
    NHSER26NM
  ) %>%
  dplyr::distinct()

icb_name_lookup <- nhser_lookup %>%
  dplyr::filter(!is.na(ICB26NM), ICB26NM != "") %>%
  dplyr::transmute(
    ICB_Parent_Key = normalise_icb_parent_name(ICB26NM),
    ICB26CD_Fallback = ICB26CD,
    ICB26NM_Fallback = ICB26NM
  ) %>%
  dplyr::distinct()

region_name_lookup <- nhser_lookup %>%
  dplyr::filter(!is.na(NHSER26NM), NHSER26NM != "") %>%
  dplyr::transmute(
    Region_Key = normalise_region_name(NHSER26NM),
    NHS_Region_Canonical = NHSER26NM
  ) %>%
  dplyr::distinct()

practice_geo <- practice_geo_raw %>%
  dplyr::transmute(
    Practice_Code = trimws(`Practice Code`),
    Payment_Region = trimws(`NHS England (Region) Name`),
    Sub_ICB_Code = trimws(`Sub ICB Code`),
    Sub_ICB_Name = trimws(`Sub ICB Name`),
    SICBL_Name_Key = normalise_key(`Sub ICB Name`),
    ICB_Parent_Key = normalise_icb_parent_name(`Sub ICB Name`),
    Region_Key = normalise_region_name(`NHS England (Region) Name`)
  ) %>%
  dplyr::filter(!is.na(Practice_Code), Practice_Code != "") %>%
  dplyr::distinct(Practice_Code, .keep_all = TRUE) %>%
  dplyr::left_join(sicbl_to_icb, by = "SICBL_Name_Key") %>%
  dplyr::left_join(icb_name_lookup, by = "ICB_Parent_Key") %>%
  dplyr::left_join(region_name_lookup, by = "Region_Key") %>%
  dplyr::mutate(
    ICB26CD = dplyr::coalesce(ICB26CD, ICB26CD_Fallback),
    ICB26NM = dplyr::coalesce(ICB26NM, ICB26NM_Fallback),
    NHS_Region = dplyr::coalesce(NHS_Region_Canonical, NHSER26NM)
  )

icb_match_rate <- mean(
  !is.na(practice_geo$ICB26CD) & practice_geo$ICB26CD != "",
  na.rm = TRUE
)

region_match_rate <- mean(
  !is.na(practice_geo$NHS_Region) & practice_geo$NHS_Region != "",
  na.rm = TRUE
)

if (!is.finite(icb_match_rate) || icb_match_rate < 0.95) {
  stop(
    sprintf(
      "Only %.1f%% of practices could be mapped to an ICB26. Check the ONS SICBL26 lookup and payments2425.csv.",
      100 * icb_match_rate
    )
  )
}

if (!is.finite(region_match_rate) || region_match_rate < 0.95) {
  stop(
    sprintf(
      "Only %.1f%% of practices could be mapped to an NHS England region. Check region naming in payments2425.csv.",
      100 * region_match_rate
    )
  )
}

if (icb_match_rate < 1) {
  warning(sprintf("%.1f%% of practices were mapped to ICB26.", 100 * icb_match_rate))
}

if (region_match_rate < 1) {
  warning(sprintf("%.1f%% of practices were mapped to NHS England regions.", 100 * region_match_rate))
}

practice_region_lookup <- practice_geo %>%
  dplyr::filter(!is.na(NHS_Region), NHS_Region != "") %>%
  dplyr::select(Practice_Code, NHS_Region) %>%
  dplyr::distinct()

practice_icb_lookup <- practice_geo %>%
  dplyr::filter(!is.na(ICB26CD), ICB26CD != "", !is.na(ICB26NM), ICB26NM != "") %>%
  dplyr::transmute(
    Practice_Code,
    ICB26CD,
    ICB26NM,
    ICB_Key = ICB26CD,
    ICB = ICB26NM
  ) %>%
  dplyr::distinct()
