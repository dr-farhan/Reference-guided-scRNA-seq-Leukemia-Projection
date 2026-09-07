message_time("Projecting query cells with BoneMarrowMap/Symphony ...")
query <- BoneMarrowMap::map_Query(
  query = query_input,
  ref_obj = ref,
  vars = ".analysis_sample",
  do_normalize = TRUE,
  do_umap = TRUE,
  verbose = TRUE
)
rm(query_input)
invisible(gc())

message_time("Calculating per-sample mapping error ...")
query <- BoneMarrowMap::calculate_MappingError(
  query = query,
  reference = ref,
  MAD_threshold = mapping_mad_threshold,
  threshold_by_donor = TRUE,
  donor_key = ".analysis_sample"
)

message_time("Transferring fine and broad cell-type labels ...")
query <- BoneMarrowMap::predict_CellTypes(
  query_obj = query,
  ref_obj = ref,
  ref_label = "CellType_Annotation",
  k = knn_k,
  mapQC_col = "mapping_error_QC",
  initial_label = "initial_CellType",
  final_label = "predicted_CellType",
  include_broad = TRUE
)

message_time("Transferring hematopoietic pseudotime ...")
query <- BoneMarrowMap::predict_Pseudotime(
  query_obj = query,
  ref_obj = ref,
  k = knn_k,
  mapQC_class = "mapping_error_QC",
  initial_label = "initial_Pseudotime",
  final_label = "predicted_Pseudotime"
)
