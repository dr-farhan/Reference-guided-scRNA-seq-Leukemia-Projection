input_files <- resolve_input_files(
  input_paths, input_pattern, recursive = search_input_recursively
)
if (!length(input_files)) {
  stop(
    "No input RDS files found. Set input_paths or AML_INPUT. Current value: ",
    paste(input_paths, collapse = ", ")
  )
}

read_seurat <- function(path, input_id) {
  message_time("Loading ", path)
  object <- readRDS(path)
  if (!inherits(object, "Seurat")) stop(path, " is not a Seurat object.")

  if (!"RNA" %in% Seurat::Assays(object)) {
    if (!source_rna_assay %in% Seurat::Assays(object)) {
      stop(
        "No RNA assay in ", path, ". Available assays: ",
        paste(Seurat::Assays(object), collapse = ", ")
      )
    }
    source_counts <- get_counts(object, source_rna_assay)
    object[["RNA"]] <- Seurat::CreateAssayObject(counts = source_counts)
  }

  DefaultAssay(object) <- "RNA"
  object <- join_rna_layers_if_needed(object)
  counts <- get_counts(object, "RNA")
  if (!nrow(counts) || !ncol(counts)) stop("RNA counts are empty in ", path)

  if (!"percent.mt" %in% colnames(object[[]])) {
    object[["percent.mt"]] <- PercentageFeatureSet(object, pattern = "^MT-")
  }

  if (!is.null(sample_meta_column) && sample_meta_column %in% colnames(object[[]])) {
    object$.analysis_sample <- as.character(object[[]][[sample_meta_column]])
  } else {
    object$.analysis_sample <- input_id
  }
  object$.input_file <- normalizePath(path)
  object <- RenameCells(object, add.cell.id = input_id)

  if (apply_input_qc) {
    keep <- object$nFeature_RNA >= min_features &
      object$nFeature_RNA <= max_features &
      object$percent.mt <= max_percent_mt
    keep[is.na(keep)] <- FALSE
    object <- subset(object, cells = colnames(object)[keep])
  }

  if (!ncol(object)) stop("No cells remain after input QC for ", path)
  object
}

input_ids <- make.unique(
  sanitize_name(tools::file_path_sans_ext(basename(input_files))),
  sep = "_"
)
input_objects <- Map(read_seurat, input_files, input_ids)
if (length(input_objects) == 1L) {
  query_input <- input_objects[[1]]
} else {
  message_time("Merging ", length(input_objects), " Seurat objects ...")
  query_input <- Reduce(
    function(x, y) merge(x, y, merge.data = FALSE),
    input_objects
  )
  query_input <- join_rna_layers_if_needed(query_input)
}
rm(input_objects)
invisible(gc())

message_time(
  "Input contains ", format(ncol(query_input), big.mark = ","), " cells and ",
  length(unique(query_input$.analysis_sample)), " sample(s)."
)

# Save input QC table before BoneMarrowMap rebuilds the RNA assay.
input_qc <- query_input[[]] %>%
  rownames_to_column("cell") %>%
  select(
    cell, .analysis_sample, .input_file, nCount_RNA, nFeature_RNA,
    percent.mt, everything()
  )
readr::write_csv(input_qc, file.path(table_dir, "00_input_metadata.csv.gz"))

