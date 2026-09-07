# Read resolved configuration and load the same analysis packages as V2.
required_packages <- c(
  "Seurat", "SeuratObject", "BoneMarrowMap", "symphony", "dplyr", "tidyr",
  "tibble", "purrr", "readr", "stringr", "ggplot2", "patchwork", "ggrepel",
  "RColorBrewer", "scales", "curl", "yaml"
)
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages)) {
  stop("Missing packages: ", paste(missing_packages, collapse = ", "))
}
suppressPackageStartupMessages({
  library(Seurat)
  library(SeuratObject)
  library(BoneMarrowMap)
  library(dplyr)
  library(tidyr)
  library(tibble)
  library(purrr)
  library(readr)
  library(stringr)
  library(ggplot2)
  library(patchwork)
  library(ggrepel)
  library(RColorBrewer)
})
list2env(config$analysis, envir = .GlobalEnv)
input_paths <- unlist(config$input_paths)
input_pattern <- config$input_pattern
search_input_recursively <- config$search_input_recursively
output_dir <- config$output_dir
reference_cache_dir <- config$reference_cache_dir
figure_dir <- file.path(output_dir, "figures")
table_dir <- file.path(output_dir, "tables")
object_dir <- file.path(output_dir, "objects")
for (path in c(output_dir, figure_dir, table_dir, object_dir)) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
}
reference_rds <- file.path(reference_cache_dir, "BoneMarrowMap_SymphonyReference.rds")
uwot_model <- file.path(reference_cache_dir, "BoneMarrowMap_uwot_model.uwot")
set.seed(seed)
options(stringsAsFactors = FALSE, future.globals.maxSize = 8 * 1024^3)
source(file.path(script_dir, "utils.R"))
