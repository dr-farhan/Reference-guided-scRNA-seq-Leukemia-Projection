message_time("Writing annotation tables ...")

cell_annotations <- query[[]] %>%
  rownames_to_column("cell") %>%
  left_join(
    as.data.frame(Embeddings(query, "umap_projected")) %>%
      setNames(c("projected_UMAP_1", "projected_UMAP_2")) %>%
      rownames_to_column("cell"),
    by = "cell"
  ) %>%
  left_join(
    as.data.frame(Embeddings(query, "umap_patient")) %>%
      setNames(c("native_UMAP_1", "native_UMAP_2")) %>%
      rownames_to_column("cell"),
    by = "cell"
  )

readr::write_csv(
  cell_annotations,
  file.path(table_dir, "cell_annotations.csv.gz")
)
readr::write_csv(
  cluster_summary,
  file.path(table_dir, "cluster_summary.csv")
)
readr::write_csv(
  composition,
  file.path(table_dir, "cell_state_composition.csv")
)
if (exists("cluster_lineage")) {
  readr::write_csv(
    cluster_lineage,
    file.path(table_dir, "cluster_by_reference_lineage_proportions.csv")
  )
}

methods_note <- c(
  "Reference-guided scRNA-seq leukemia projection",
  paste("Cells:", ncol(query)),
  paste("Samples:", paste(unique(query$.analysis_sample), collapse = ", ")),
  paste("Mapping MAD cutoff:", mapping_mad_threshold),
  paste("KNN probability cutoff:", knn_probability_cutoff),
  "Annotations describe similarity to normal hematopoietic reference states.",
  "Reference projection alone does not establish malignancy."
)
writeLines(methods_note, file.path(output_dir, "METHODS_AND_INTERPRETATION.txt"))
writeLines(capture.output(sessionInfo()), file.path(output_dir, "sessionInfo.txt"))
