#!/usr/bin/env Rscript
# Compare every retained per-cell field and independently rebuild lineage tables.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3L) stop("Usage: compare_v2.R ORIGINAL_RESULTS NEW_RESULTS REPORT_DIR")
suppressPackageStartupMessages({library(readr); library(dplyr); library(tidyr)})
old <- read_csv(file.path(args[1], "tables/cell_annotations.csv.gz"), show_col_types = FALSE)
new <- read_csv(file.path(args[2], "tables/cell_annotations.csv.gz"), show_col_types = FALSE)
stopifnot(setequal(old$cell, new$cell), !anyDuplicated(new$cell))
old <- old[match(new$cell, old$cell), ]
# These fields deliberately change when candidate-state overrides are removed.
changed <- c("final_annotation", "cluster_interpretation", ".input_file")
retained <- setdiff(names(new), changed)
stopifnot(all(retained %in% names(old)))
comparison <- lapply(retained, function(field) {
  a <- old[[field]]; b <- new[[field]]
  numeric <- is.numeric(a) && is.numeric(b)
  error <- if (numeric && any(is.finite(a) & is.finite(b))) {
    max(abs(a[is.finite(a) & is.finite(b)] - b[is.finite(a) & is.finite(b)]))
  } else NA_real_
  data.frame(field = field,
             equal = isTRUE(all.equal(a, b, tolerance = 1e-8, check.attributes = FALSE)),
             max_absolute_error = error)
}) %>% bind_rows()
stopifnot(all(new$final_annotation == old$major_lineage))
expected_composition <- old %>%
  count(.analysis_sample, final_annotation = major_lineage, name = "n_cells") %>%
  group_by(.analysis_sample) %>% mutate(fraction = n_cells / sum(n_cells)) %>% ungroup()
observed_composition <- read_csv(file.path(args[2], "tables/cell_state_composition.csv"), show_col_types = FALSE)
comparison <- bind_rows(comparison, data.frame(
  field = "lineage_composition_recomputed",
  equal = isTRUE(all.equal(as.data.frame(expected_composition), as.data.frame(observed_composition), tolerance = 1e-8)),
  max_absolute_error = NA_real_
))
expected_clusters <- old %>% group_by(.analysis_sample, patient_cluster) %>%
  summarise(n_cells = n(), mapping_pass_fraction = mean(mapping_usable, na.rm = TRUE), .groups = "drop") %>%
  mutate(patient_cluster = as.character(patient_cluster)) %>% arrange(.analysis_sample, patient_cluster)
observed_clusters <- read_csv(file.path(args[2], "tables/cluster_summary.csv"), show_col_types = FALSE) %>%
  select(all_of(names(expected_clusters))) %>% mutate(patient_cluster = as.character(patient_cluster)) %>%
  arrange(.analysis_sample, patient_cluster)
comparison <- bind_rows(comparison, data.frame(
  field = "cluster_counts_and_mapping_qc",
  equal = isTRUE(all.equal(as.data.frame(expected_clusters), as.data.frame(observed_clusters), tolerance = 1e-8)),
  max_absolute_error = NA_real_
))
dir.create(args[3], recursive = TRUE, showWarnings = FALSE)
write_csv(comparison, file.path(args[3], "v2_comparison.csv"))
print(comparison, row.names = FALSE)
if (!all(comparison$equal)) stop("Some retained outputs differ; inspect v2_comparison.csv")
cat("PASS: all retained fields and recomputed summaries agree with V2.\n")
