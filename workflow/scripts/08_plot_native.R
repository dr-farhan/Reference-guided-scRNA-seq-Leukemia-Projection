# Figure 7: native UMAP overviews for all cells and for each treatment cohort.
# Subsets retain the same combined-data UMAP coordinates, enabling direct visual
# comparison between treated and control cohorts.
cluster_colors <- manual_palette(unique(query$patient_cluster))
lineage_colors <- manual_palette(unique(query$major_lineage))
interpretation_colors <- manual_palette(unique(query$cluster_interpretation))

make_native_overview <- function(object, overview_title) {
  object_metadata <- object[[]]
  overview_subtitle <- paste0(
    "N = ", format(ncol(object), big.mark = ","), " cells; ",
    length(unique(object_metadata$.analysis_sample)), " samples"
  )
  p_cluster <- DimPlot(
    object, reduction = "umap_patient", group.by = "patient_cluster",
    cols = cluster_colors, label = TRUE, repel = TRUE, label.size = 2.7,
    raster = FALSE, pt.size = point_size
  ) + NoAxes() + ggtitle("Native clusters") + theme_publication() +
    theme(legend.position = "none")
  p_lineage <- DimPlot(
    object, reduction = "umap_patient", group.by = "major_lineage",
    cols = lineage_colors, label = TRUE, repel = TRUE, label.size = 2.5,
    raster = FALSE, pt.size = point_size
  ) + NoAxes() + ggtitle("Transferred lineages") + theme_publication() +
    theme(legend.text = element_text(size = 6.2))
  p_interpretation <- DimPlot(
    object, reduction = "umap_patient", group.by = "cluster_interpretation",
    cols = interpretation_colors, label = TRUE, repel = TRUE, label.size = 2.5,
    raster = FALSE, pt.size = point_size
  ) + NoAxes() + ggtitle("Cluster interpretation") + theme_publication() +
    theme(legend.text = element_text(size = 6.2))
  p_cluster + p_lineage + p_interpretation +
    plot_annotation(title = overview_title, subtitle = overview_subtitle)
}

treatment_groups <- unique(as.character(query$.treatment_group))
treated_group <- if ("DAC" %in% treatment_groups) {
  "DAC"
} else if ("AZA" %in% treatment_groups) {
  "AZA"
} else {
  setdiff(treatment_groups, c("Control", "Other"))[1]
}
if (is.na(treated_group) || !nzchar(treated_group)) treated_group <- "Treated"

combined_07_stem <- paste0(
  "07_native_UMAPs_combined_", sanitize_name(treated_group), "_control"
)
save_plot(
  make_native_overview(
    query,
    paste0("Native UMAP overview: ", treated_group, " and control")
  ),
  combined_07_stem, 17, 6.3
)

for (current_group in intersect(c(treated_group, "Control"), treatment_groups)) {
  group_cells <- colnames(query)[query$.treatment_group == current_group]
  group_object <- subset(query, cells = group_cells)
  group_file_label <- if (identical(current_group, "Control")) {
    "control"
  } else {
    sanitize_name(current_group)
  }
  save_plot(
    make_native_overview(
      group_object,
      paste0("Native UMAP overview: ", current_group, " samples")
    ),
    paste0("07_native_UMAPs_", group_file_label, "_samples"),
    17, 6.3
  )
}

# Figure 8: native UMAP with transferred major lineages.
p_native_final <- DimPlot(
  query,
  reduction = "umap_patient",
  group.by = "final_annotation",
  cols = state_colors,
  label = TRUE,
  repel = TRUE,
  label.size = 2.8,
  raster = FALSE,
  pt.size = point_size
) + NoAxes() +
  ggtitle("Native patient UMAP: major lineages") +
  labs(
    subtitle = paste0("Total N = ", format(ncol(query), big.mark = ","))
  ) +
  theme_publication() + theme(legend.text = element_text(size = 7))
save_plot(p_native_final, "08_native_UMAP_final_annotations", 10.5, 7)

