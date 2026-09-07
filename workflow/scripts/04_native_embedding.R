message_time("Computing native patient UMAP and graph-based clusters ...")
native_assay <- "SCT_native"
native_ok <- TRUE
query <- tryCatch(
  {
    SCTransform(
      query,
      assay = "RNA",
      new.assay.name = native_assay,
      vars.to.regress = "percent.mt",
      verbose = FALSE,
      conserve.memory = TRUE
    )
  },
  error = function(e) {
    native_ok <<- FALSE
    warning("SCTransform failed; falling back to log normalization: ", e$message)
    query
  }
)

if (native_ok) {
  DefaultAssay(query) <- native_assay
} else {
  DefaultAssay(query) <- "RNA"
  query <- NormalizeData(query, verbose = FALSE)
  query <- FindVariableFeatures(query, nfeatures = 3000, verbose = FALSE)
  query <- ScaleData(query, features = VariableFeatures(query), verbose = FALSE)
}

max_pcs <- min(
  native_npcs,
  ncol(query) - 1L,
  max(2L, length(VariableFeatures(query)) - 1L)
)
native_dims <- seq_len(max_pcs)
query <- RunPCA(
  query, npcs = max_pcs, reduction.name = "pca_patient", verbose = FALSE
)
query <- RunUMAP(
  query,
  reduction = "pca_patient",
  dims = native_dims,
  reduction.name = "umap_patient",
  reduction.key = "patientUMAP_",
  min.dist = native_umap_min_dist,
  seed.use = seed,
  verbose = FALSE
)
query <- FindNeighbors(
  query,
  reduction = "pca_patient",
  dims = native_dims,
  graph.name = c("patient_nn", "patient_snn"),
  verbose = FALSE
)
query <- FindClusters(
  query,
  graph.name = "patient_snn",
  resolution = native_resolution,
  random.seed = seed,
  verbose = FALSE
)
query$patient_cluster <- as.character(Idents(query))

# Summarise transferred lineages within each sample and native cluster.
cluster_summary <- query[[]] %>%
  rownames_to_column("cell") %>%
  group_by(.analysis_sample, patient_cluster) %>%
  summarise(
    n_cells = n(),
    mapping_pass_fraction = mean(mapping_usable, na.rm = TRUE),
    dominant_major_lineage = dominant_value(major_lineage),
    .groups = "drop"
  ) %>%
  mutate(
    cluster_interpretation = dominant_major_lineage,
    cluster_key = paste(.analysis_sample, patient_cluster, sep = "::")
  )

cluster_lookup <- cluster_summary %>%
  select(cluster_key, cluster_interpretation)
query_meta <- query[[]] %>%
  rownames_to_column("cell") %>%
  mutate(cluster_key = paste(.analysis_sample, patient_cluster, sep = "::")) %>%
  left_join(cluster_lookup, by = "cluster_key") %>%
  select(cell, cluster_key, cluster_interpretation) %>%
  column_to_rownames("cell")
query <- AddMetaData(query, query_meta)

# Return to RNA for expression visualization.
DefaultAssay(query) <- "RNA"
