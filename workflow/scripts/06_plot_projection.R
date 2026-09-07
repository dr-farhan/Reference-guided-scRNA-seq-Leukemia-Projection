# Prepare projected/reference coordinates for custom overlays.
ref_df <- as.data.frame(ref$umap$embedding)
colnames(ref_df)[1:2] <- c("UMAP_1", "UMAP_2")
if (nrow(ref_df) > reference_plot_max_cells) {
  ref_df <- ref_df[sample(seq_len(nrow(ref_df)), reference_plot_max_cells), ]
}

projected_df <- as.data.frame(Embeddings(query, "umap_projected")) %>%
  setNames(c("UMAP_1", "UMAP_2")) %>%
  rownames_to_column("cell") %>%
  left_join(query[[]] %>% rownames_to_column("cell"), by = "cell")

state_levels <- sort(unique(projected_df$final_annotation))
state_colors <- manual_palette(state_levels)
projected_centroids <- projected_df %>%
  filter(mapping_usable) %>%
  group_by(final_annotation) %>%
  summarise(
    UMAP_1 = median(UMAP_1), UMAP_2 = median(UMAP_2), .groups = "drop"
  )

# Figure 3: final classes projected onto reference.
p_projected_final <- ggplot() +
  geom_point(
    data = ref_df,
    aes(UMAP_1, UMAP_2),
    color = "grey88", size = 0.06, alpha = 0.40
  ) +
  geom_point(
    data = projected_df %>% filter(mapping_usable),
    aes(UMAP_1, UMAP_2, color = final_annotation),
    size = point_size, alpha = 0.75
  ) +
  geom_text_repel(
    data = projected_centroids,
    aes(UMAP_1, UMAP_2, label = final_annotation, color = final_annotation),
    size = 2.6, fontface = "bold", max.overlaps = Inf,
    min.segment.length = 0, box.padding = 0.35, show.legend = FALSE
  ) +
  scale_color_manual(values = state_colors, drop = FALSE) +
  coord_equal() +
  labs(
    title = "AML query projected onto healthy BoneMarrowMap",
    subtitle = paste0(
      "Lineage labels require mapping QC and KNN probability ≥ ",
      knn_probability_cutoff
    ),
    x = "Reference UMAP 1", y = "Reference UMAP 2", color = "Annotation"
  ) + theme_publication() + theme(legend.text = element_text(size = 7))
save_plot(p_projected_final, "03_projected_final_annotations", 10.5, 7)

# Figure 4: projected broad and fine cell types.
p_projected_broad <- DimPlot(
  subset(query, subset = mapping_usable),
  reduction = "umap_projected",
  group.by = "predicted_CellType_Broad",
  label = TRUE, repel = TRUE, label.size = 3,
  raster = FALSE, pt.size = point_size
) + NoAxes() + ggtitle("Projected broad lineage") + theme_publication()

p_projected_fine <- DimPlot(
  subset(query, subset = mapping_usable),
  reduction = "umap_projected",
  group.by = "predicted_CellType",
  label = FALSE,
  raster = FALSE, pt.size = point_size
) + NoAxes() + ggtitle("Projected fine cell state") +
  theme_publication() + theme(legend.text = element_text(size = 5.5))
save_plot(
  p_projected_broad + p_projected_fine,
  "04_projected_reference_celltypes", 16, 6.5
)

# Retain the pseudotime panel from original Figure 5.
p_pseudotime <- FeaturePlot(
  subset(query, subset = mapping_usable),
  reduction = "umap_projected",
  features = "predicted_Pseudotime",
  order = TRUE,
  raster = FALSE,
  pt.size = point_size
) + scale_color_gradientn(colors = rev(brewer.pal(11, "RdBu"))) +
  NoAxes() + ggtitle("Hematopoietic pseudotime") + theme_publication()

save_plot(p_pseudotime, "05_projected_pseudotime", 7, 6.5)
