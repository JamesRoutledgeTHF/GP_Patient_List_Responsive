# Build practice -> NHS England region and practice -> ICB lookups.
#
# For practice-level analyses (GP workforce, registered patients and payments),
# the geography assignment comes directly from payments2425.csv.
#
# No ONS LSOA/SICBL crosswalk is used to assign practices to an ICB.

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

normalise_icb_name <- function(x) {
  x <- toupper(trimws(as.character(x)))
  x <- gsub("\\s+-\\s+[A-Z0-9]+$", "", x)
  x <- gsub("^NHS\\s+", "", x)
  x <- gsub("\\s+INTEGRATED CARE BOARD$", "", x)
  x <- gsub("\\s+ICB$", "", x)
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
    NHS_Region = normalise_region_name(`NHS England (Region) Name`),
    ICB_Key = normalise_icb_name(`Sub ICB Name`),
    ICB = sub(
      "\\s+-\\s+[A-Z0-9]+$",
      "",
      trimws(`Sub ICB Name`)
    )
  ) %>%
  dplyr::filter(!is.na(Practice_Code), Practice_Code != "") %>%
  dplyr::distinct(Practice_Code, .keep_all = TRUE)

if (any(is.na(practice_geo$ICB_Key)) || any(practice_geo$ICB_Key == "")) {
  stop("Some practices in payments2425.csv do not have a usable ICB name.")
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
    Sub_ICB_Name
  ) %>%
  dplyr::distinct()
