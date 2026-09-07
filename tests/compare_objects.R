#!/usr/bin/env Rscript
# Verify assay matrices and native graph/PCA data, beyond exported annotations.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3L) stop("Usage: compare_objects.R ORIGINAL_RDS NEW_RDS REPORT_JSON")
suppressPackageStartupMessages({library(Seurat); library(SeuratObject)})
old <- readRDS(args[1])
new <- readRDS(args[2])
checks <- c(cell_order = identical(colnames(old), colnames(new)))
for (assay in c("RNA", "SCT_native")) {
  checks[paste0(assay, "_features")] <- identical(rownames(old[[assay]]), rownames(new[[assay]]))
  checks[paste0(assay, "_variable_features")] <- identical(VariableFeatures(old[[assay]]), VariableFeatures(new[[assay]]))
  for (layer in c("counts", "data", "scale.data")) {
    a <- GetAssayData(old, assay = assay, layer = layer)
    b <- GetAssayData(new, assay = assay, layer = layer)
    checks[paste(assay, layer, sep = "_")] <- identical(a, b)
  }
}
for (reduction in c("pca_patient", "umap_patient", "umap_projected")) {
  checks[paste0(reduction, "_embeddings")] <- identical(Embeddings(old, reduction), Embeddings(new, reduction))
}
checks["pca_loadings"] <- identical(Loadings(old, "pca_patient"), Loadings(new, "pca_patient"))
for (graph in c("patient_nn", "patient_snn")) {
  checks[graph] <- identical(old[[graph]], new[[graph]])
}
dir.create(dirname(args[3]), recursive = TRUE, showWarnings = FALSE)
jsonlite::write_json(as.list(checks), args[3], auto_unbox = TRUE, pretty = TRUE)
print(checks)
stopifnot(all(checks))
