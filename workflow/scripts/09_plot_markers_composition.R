# Figure 11: marker dot plot.
marker_panel <- unique(c(
  "HLF", "HOPX", "MECOM", "MEIS1", "SPINK2", "MMRN1", "ADGRG1", "CD34",
  "KIT", "FLT3", "GATA2", "MPO", "ELANE", "AZU1", "PRTN3", "CTSG",
  "CD14", "FCGR3A", "CSF1R", "LST1", "S100A8", "S100A9",
  "CD3D", "CD3E", "MS4A1", "CD79A", "NKG7", "GNLY", "FCER1A",
  "GZMB", "PPBP", "PF4", "HBB", "GYPA"
))
marker_panel <- intersect(marker_panel, rownames(query))
if (length(marker_panel) >= 3L) {
  p_dot <- DotPlot(
    query,
    features = marker_panel,
    group.by = "final_annotation",
    assay = "RNA",
    dot.scale = 5
  ) +
    scale_color_gradient2(
      low = "#2166AC", mid = "white", high = "#B2182B", midpoint = 0
    ) +
    RotatedAxis() +
    labs(
      title = "Marker validation of mapped lineages",
      x = NULL, y = NULL, color = "Scaled expression", size = "% expressing"
    ) + theme_publication() +
    theme(axis.text.x = element_text(size = 7), axis.text.y = element_text(size = 8))
  save_plot(p_dot, "11_marker_validation_dotplot", 14, 6.5)
}

# Figure 12: composition by sample.
composition <- query[[]] %>%
  rownames_to_column("cell") %>%
  count(.analysis_sample, final_annotation, name = "n_cells") %>%
  group_by(.analysis_sample) %>%
  mutate(fraction = n_cells / sum(n_cells)) %>%
  ungroup()
p_composition <- ggplot(
  composition,
  aes(x = .analysis_sample, y = fraction, fill = final_annotation)
) +
  geom_col(width = 0.75, color = "white", linewidth = 0.15) +
  scale_fill_manual(values = state_colors, drop = FALSE) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
  labs(
    title = "Cell-state composition",
    subtitle = paste0(
      "Total N = ", format(ncol(query), big.mark = ","), "; ",
      length(unique(query$.analysis_sample)), " samples"
    ),
    x = NULL, y = "Fraction of captured cells", fill = "Annotation"
  ) + theme_publication() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
save_plot(p_composition, "12_cell_state_composition", 10, 6)

