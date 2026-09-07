# Per-sample native UMAP panels when multiple samples were loaded.
sample_ids <- unique(query$.analysis_sample)
for (sample_id in sample_ids) {
  sample_cells <- colnames(query)[query$.analysis_sample == sample_id]
  sample_object <- subset(query, cells = sample_cells)
  sample_colors <- manual_palette(sample_object$final_annotation)
  p_sample <- DimPlot(
    sample_object,
    reduction = "umap_patient",
    group.by = "final_annotation",
    cols = sample_colors,
    label = TRUE,
    repel = TRUE,
    label.size = 2.8,
    raster = FALSE,
    pt.size = point_size
  ) + NoAxes() + ggtitle(paste0(sample_id, ": native UMAP annotations")) +
    theme_publication() + theme(legend.text = element_text(size = 7))
  save_plot(
    p_sample,
    paste0("sample_", sanitize_name(sample_id), "_native_UMAP_annotations"),
    9, 6.5
  )
}

