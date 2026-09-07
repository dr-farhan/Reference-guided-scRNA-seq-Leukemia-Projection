#!/usr/bin/env Rscript
# Each Snakemake rule runs in a fresh R process; checkpoint the RNG as well as data.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 5L) {
  stop("Usage: run_stage.R STAGE CONFIG INPUT_STATE OUTPUT_STATE SCRIPT_DIR")
}
stage <- args[1]
config <- yaml::read_yaml(args[2])
script_dir <- args[5]
source(file.path(script_dir, "bootstrap.R"))
if (args[3] != "-") {
  state <- readRDS(args[3])
  list2env(state, envir = .GlobalEnv)
  assign(".Random.seed", rng_state, envir = .GlobalEnv)
  rm(state)
}
run_module <- function(name) source(file.path(script_dir, name), local = .GlobalEnv)
if (stage == "prepare") {
  run_module("01_prepare_input.R")
  query <- query_input
  rm(query_input)
} else if (stage == "project") {
  ref <- readRDS(reference_rds)
  ref$save_uwot_path <- uwot_model
  query_input <- query
  run_module("02_project_reference.R")
  run_module("03_annotate_lineages.R")
} else if (stage == "native") {
  run_module("04_native_embedding.R")
} else if (stage == "report") {
  ref <- readRDS(reference_rds)
  ref$save_uwot_path <- uwot_model
  ReferenceSeuratObj <- BoneMarrowMap::create_ReferenceObject(ref)
  for (module in c(
    "05_plot_reference_qc.R", "06_plot_projection.R", "07_plot_density.R",
    "08_plot_native.R", "09_plot_markers_composition.R", "10_plot_concordance.R",
    "11_plot_samples.R", "12_export_results.R"
  )) run_module(module)
} else {
  stop("Unknown stage: ", stage)
}
if (stage != "report") {
  state <- list(query = query, input_files = input_files, rng_state = .Random.seed)
  if (exists("cluster_summary")) state$cluster_summary <- cluster_summary
  saveRDS(state, args[4], compress = FALSE)
} else {
  figures <- list.files(figure_dir, pattern = "\\.(pdf|png)$", full.names = TRUE)
  manifest <- data.frame(
    file = basename(figures), bytes = file.info(figures)$size,
    md5 = unname(tools::md5sum(figures))
  )
  readr::write_csv(manifest, args[4])
}
message_time("Completed stage: ", stage)
