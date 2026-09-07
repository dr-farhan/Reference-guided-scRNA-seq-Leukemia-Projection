# Figure 13: publication-oriented lineage-composition heatmaps. Aggregate the
# global native clusters before plotting, avoiding hundreds of sample::cluster
# columns. Percentage labels are shown only for contributions of at least 10%.
summarise_cluster_lineage <- function(metadata) {
  metadata %>%
    filter(mapping_usable) %>%
    count(patient_cluster, major_lineage, name = "n_cells") %>%
    group_by(patient_cluster) %>%
    mutate(
      cluster_n = sum(n_cells),
      proportion = n_cells / cluster_n,
      cluster_label = paste0(
        "C", patient_cluster, "\nN=", format(cluster_n, big.mark = ",")
      )
    ) %>%
    ungroup()
}

make_lineage_heatmap <- function(lineage_data, plot_title, plot_subtitle) {
  cluster_order <- ordered_cluster_ids(lineage_data$patient_cluster)
  cluster_labels <- lineage_data %>%
    distinct(patient_cluster, cluster_label)
  label_lookup <- stats::setNames(
    cluster_labels$cluster_label, cluster_labels$patient_cluster
  )
  lineage_data$cluster_label <- factor(
    lineage_data$cluster_label,
    levels = unname(label_lookup[cluster_order])
  )
  lineage_data$major_lineage <- factor(
    lineage_data$major_lineage,
    levels = rev(sort(unique(as.character(lineage_data$major_lineage))))
  )
  ggplot(
    lineage_data,
    aes(x = cluster_label, y = major_lineage, fill = proportion)
  ) +
    geom_tile(color = "white", linewidth = 0.30) +
    geom_text(
      data = lineage_data %>% filter(proportion >= 0.10),
      aes(label = scales::percent(proportion, accuracy = 1)),
      size = 2.4
    ) +
    scale_fill_gradientn(
      colors = c("white", "#92C5DE", "#2166AC"),
      limits = c(0, 1), labels = scales::percent_format(accuracy = 1)
    ) +
    labs(
      title = plot_title,
      subtitle = plot_subtitle,
      x = "Native cluster and cluster size",
      y = "Transferred reference lineage",
      fill = "Within-cluster\nproportion"
    ) +
    theme_publication(base_size = 9) +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1, size = 7),
      axis.text.y = element_text(size = 8),
      panel.grid = element_blank()
    )
}

mapped_metadata <- query[[]] %>% rownames_to_column("cell")
cluster_lineage <- summarise_cluster_lineage(mapped_metadata)
if (nrow(cluster_lineage)) {
  combined_cluster_count <- n_distinct(cluster_lineage$patient_cluster)
  combined_heatmap <- make_lineage_heatmap(
    cluster_lineage,
    "Transferred lineage composition within native clusters",
    paste0(
      "All samples combined; mapping-usable N = ",
      format(sum(mapped_metadata$mapping_usable), big.mark = ",")
    )
  )
  save_plot(
    combined_heatmap,
    "13_cluster_by_reference_lineage_heatmap",
    max(10, min(20, 0.48 * combined_cluster_count + 5)),
    max(6, 0.38 * n_distinct(cluster_lineage$major_lineage) + 3)
  )
}

cluster_lineage_by_treatment <- mapped_metadata %>%
  filter(mapping_usable) %>%
  group_by(.treatment_group) %>%
  group_split()
for (condition_metadata in cluster_lineage_by_treatment) {
  current_group <- unique(as.character(condition_metadata$.treatment_group))
  if (!length(current_group) || identical(current_group, "Other")) next
  condition_lineage <- summarise_cluster_lineage(condition_metadata)
  if (!nrow(condition_lineage)) next
  condition_file_label <- if (identical(current_group, "Control")) {
    "control"
  } else {
    sanitize_name(current_group)
  }
  condition_heatmap <- make_lineage_heatmap(
    condition_lineage,
    paste0(
      "Transferred lineage composition within native clusters: ",
      current_group
    ),
    paste0(
      "Mapping-usable N = ",
      format(sum(condition_metadata$mapping_usable), big.mark = ","),
      "; percentages are calculated within each cluster"
    )
  )
  save_plot(
    condition_heatmap,
    paste0(
      "13_cluster_by_reference_lineage_heatmap_",
      condition_file_label, "_samples"
    ),
    max(10, min(20, 0.48 * n_distinct(condition_lineage$patient_cluster) + 5)),
    max(6, 0.38 * n_distinct(condition_lineage$major_lineage) + 3)
  )
}

