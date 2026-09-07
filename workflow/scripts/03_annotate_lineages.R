metadata <- query[[]] %>% rownames_to_column("cell")
metadata$predicted_CellType <- as.character(metadata$predicted_CellType)
metadata$predicted_CellType_Broad <- as.character(
  metadata$predicted_CellType_Broad
)

metadata$mapping_usable <-
  metadata$mapping_error_QC == "Pass" &
  !is.na(metadata$predicted_CellType) &
  !is.na(metadata$predicted_CellType_prob) &
  metadata$predicted_CellType_prob >= knn_probability_cutoff

metadata$major_lineage <- pretty_label(
  ifelse(
    !is.na(metadata$predicted_CellType_Broad),
    metadata$predicted_CellType_Broad,
    metadata$predicted_CellType
  )
)
metadata$major_lineage[
  !metadata$mapping_usable | is.na(metadata$major_lineage) |
    !nzchar(metadata$major_lineage)
] <- "Low-confidence / unmapped"
metadata$final_annotation <- metadata$major_lineage
metadata$.treatment_group <- infer_treatment_group(metadata)
query <- AddMetaData(
  query,
  metadata %>%
    select(cell, mapping_usable, major_lineage, final_annotation, .treatment_group) %>%
    column_to_rownames("cell")
)
