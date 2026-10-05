# Build practice -> NHS England region and practice -> ICB lookups.
#
# For practice-level analyses (GP workforce, registered patients and payments),
# the geography assignment comes directly from payments2425.csv.
#
# April 2026 ICB assignments use the retained SICBL codes and the official
# ONS April 2026 SICBL-to-ICB relationship loaded by script 09.
# Frimley (D4U1Y) was split, so it uses explicit practice-level overrides.

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
  "NHS England (Region) code",
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

normalise_region_name <- function(x) {
  x <- toupper(trimws(as.character(x)))
  x <- gsub("^NHS ENGLAND ", "", x)
  x <- gsub(" COMMISSIONING REGION$", "", x)
  x <- gsub(" REGION$", "", x)
  x <- gsub("[^A-Z0-9 ]", "", x)
  x <- gsub("\\s+", " ", x)
  trimws(x)
}

practice_geo <- practice_geo_raw %>%
  dplyr::transmute(
    Practice_Code = trimws(`Practice Code`),
    NHS_Region_Code = trimws(`NHS England (Region) code`),
    NHS_Region_Raw = trimws(`NHS England (Region) Name`),
    Sub_ICB_Code = trimws(`Sub ICB Code`),
    Sub_ICB_Name = trimws(`Sub ICB Name`),
    NHS_Region = normalise_region_name(`NHS England (Region) Name`)
  ) %>%
  dplyr::filter(!is.na(Practice_Code), Practice_Code != "") %>%
  dplyr::distinct(Practice_Code, .keep_all = TRUE)

if (!exists("nhser_lookup") ||
    !all(c("SICBL26CDH", "ICB26CD", "ICB26NM") %in% names(nhser_lookup))) {
  stop("Source 09_Get_LSOA_NHS_Region_Lookup.R before loading practice geography.")
}

sicbl_to_icb26 <- nhser_lookup %>%
  dplyr::distinct(SICBL26CDH, ICB26CD, ICB26NM)
if (anyDuplicated(sicbl_to_icb26$SICBL26CDH)) {
  stop("Some April 2026 SICBL codes map to more than one ICB.")
}

frimley_lookup <- readr::read_csv(
  "data/frimley_practice_icb26.csv",
  show_col_types = FALSE,
  col_types = readr::cols(.default = readr::col_character())
)
if (anyDuplicated(frimley_lookup$Practice_Code)) {
  stop("Frimley practice overrides contain duplicate practice codes.")
}

practice_geo <- practice_geo %>%
  dplyr::left_join(sicbl_to_icb26, by = c("Sub_ICB_Code" = "SICBL26CDH")) %>%
  dplyr::left_join(
    frimley_lookup %>%
      dplyr::transmute(
        Practice_Code,
        Frimley_ICB26CD = ICB26CD,
        Frimley_ICB26NM = ICB26NM,
        Frimley_Mapping_Basis = Mapping_Basis
      ),
    by = "Practice_Code"
  ) %>%
  dplyr::mutate(
    ICB26CD = dplyr::if_else(
      Sub_ICB_Code == "D4U1Y", Frimley_ICB26CD, ICB26CD
    ),
    ICB26NM = dplyr::if_else(
      Sub_ICB_Code == "D4U1Y", Frimley_ICB26NM, ICB26NM
    ),
    ICB_Key = ICB26CD,
    ICB = ICB26NM,
    Mapping_Basis = dplyr::if_else(
      Sub_ICB_Code == "D4U1Y",
      Frimley_Mapping_Basis,
      "Retained SICBL code mapped to ONS April 2026 ICB"
    )
  )

unmapped_practices <- practice_geo %>%
  dplyr::filter(is.na(ICB_Key) | ICB_Key == "" | is.na(ICB) | ICB == "")
if (nrow(unmapped_practices) > 0) {
  stop(
    "Missing April 2026 ICB mappings for practices: ",
    paste(unmapped_practices$Practice_Code, collapse = ", ")
  )
}

valid_icbs <- nhser_lookup %>% dplyr::distinct(ICB26CD, ICB26NM)
if (nrow(dplyr::anti_join(
    practice_geo, valid_icbs, by = c("ICB26CD", "ICB26NM")
)) > 0) {
  stop("Practice overrides contain ICBs outside the official April 2026 lookup.")
}

if (any(is.na(practice_geo$NHS_Region)) || any(practice_geo$NHS_Region == "")) {
  stop("Some practices in payments2425.csv do not have a usable NHS England region.")
}

practice_region_lookup <- practice_geo %>%
  dplyr::select(
    Practice_Code,
    NHS_Region,
    NHS_Region_Code,
    NHS_Region_Raw
  ) %>%
  dplyr::distinct()

practice_icb_lookup <- practice_geo %>%
  dplyr::select(
    Practice_Code,
    ICB_Key,
    ICB,
    Sub_ICB_Code,
    Sub_ICB_Name,
    Mapping_Basis
  ) %>%
  dplyr::distinct()
