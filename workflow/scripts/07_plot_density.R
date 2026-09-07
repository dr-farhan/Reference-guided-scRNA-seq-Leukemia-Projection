# Figure 6: reference background plus density contours. Save one merged map and
# one independent file per sample. The explicit .env pronoun prevents a metadata
# column called sample_id from masking the loop variable inside dplyr::filter().
make_projected_density_plot <- function(query_dat, plot_title) {
  point_dat <- query_dat
  if (nrow(point_dat) > density_point_max_cells) {
    point_dat <- point_dat[
      sample(seq_len(nrow(point_dat)), density_point_max_cells),
      , drop = FALSE
    ]
  }
  ggplot() +
    geom_point(
      data = ref_df, aes(UMAP_1, UMAP_2),
      color = "grey90", size = 0.04, alpha = 0.35
    ) +
    geom_point(
      data = point_dat, aes(UMAP_1, UMAP_2),
      color = "#2166AC", size = 0.12, alpha = 0.28
    ) +
    geom_density_2d(
      data = query_dat, aes(UMAP_1, UMAP_2),
      color = "black", linewidth = 0.25, bins = 8
    ) +
    coord_equal() +
    labs(title = plot_title, x = NULL, y = NULL) +
    theme_void(base_size = 9) +
    theme(plot.title = element_text(face = "bold", hjust = 0.5))
}

merged_density_dat <- projected_df %>% filter(mapping_usable)
save_plot(
  make_projected_density_plot(
    merged_density_dat,
    "All samples combined: query-cell density on BoneMarrowMap"
  ),
  "06_projected_density_merged_all_samples", 8, 7
)

density_sample_ids <- unique(projected_df$.analysis_sample)
for (current_sample_id in density_sample_ids) {
  sample_density_dat <- projected_df %>%
    filter(
      .analysis_sample == .env$current_sample_id,
      mapping_usable
    )
  save_plot(
    make_projected_density_plot(
      sample_density_dat,
      paste0(current_sample_id, ": query-cell density on BoneMarrowMap")
    ),
    paste0(
      "06_sample_", sanitize_name(current_sample_id),
      "_projected_density"
    ),
    8, 7
  )
}

