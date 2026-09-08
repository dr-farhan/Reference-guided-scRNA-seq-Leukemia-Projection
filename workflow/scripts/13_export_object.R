message_time("Writing annotated Seurat object ...")
saveRDS(
  query,
  file.path(object_dir, "AML_BoneMarrowMap_annotated.seurat.rds"),
  compress = FALSE
)
