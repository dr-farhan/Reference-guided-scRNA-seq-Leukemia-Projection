# Figure 1: reference atlas, broad and fine labels.
p_ref_broad <- DimPlot(
  ReferenceSeuratObj,
  reduction = "umap",
  group.by = "CellType_Broad",
  label = TRUE,
  repel = TRUE,
  raster = FALSE,
  pt.size = 0.05,
  label.size = 3
) + NoAxes() + ggtitle("BoneMarrowMap reference: broad states") +
  theme_publication() + theme(legend.position = "right")

p_ref_fine <- DimPlot(
  ReferenceSeuratObj,
  reduction = "umap",
  group.by = "CellType_Annotation_formatted",
  label = FALSE,
  raster = FALSE,
  pt.size = 0.03
) + NoAxes() + ggtitle("BoneMarrowMap reference: fine states") +
  theme_publication() + theme(legend.text = element_text(size = 5))

save_plot(
  p_ref_broad + p_ref_fine + plot_layout(widths = c(1, 1.35)),
  "01_BoneMarrowMap_reference_atlas", 16, 6.5
)

# Figure 2: mapping error QC, overall and by sample.
qc_df <- query[[]] %>% rownames_to_column("cell")
p_qc_hist <- ggplot(
  qc_df,
  aes(x = mapping_error_score, fill = mapping_error_QC)
) +
  geom_histogram(bins = 150, color = NA, alpha = 0.85) +
  facet_wrap(vars(.analysis_sample), scales = "free_y") +
  scale_fill_manual(values = c(Pass = "#2166AC", Fail = "#B2182B")) +
  labs(
    title = "BoneMarrowMap mapping-error QC",
    x = "Mapping error score", y = "Cells", fill = "Mapping QC"
  ) + theme_publication()

p_qc_scatter <- ggplot(
  qc_df,
  aes(x = nFeature_RNA, y = mapping_error_score, color = mapping_error_QC)
) +
  geom_point(size = 0.15, alpha = 0.45) +
  facet_wrap(vars(.analysis_sample), scales = "free") +
  scale_color_manual(values = c(Pass = "#2166AC", Fail = "#B2182B")) +
  labs(x = "Detected genes", y = "Mapping error", color = "Mapping QC") +
  theme_publication()
save_plot(p_qc_hist / p_qc_scatter, "02_mapping_QC", 12, 8)

