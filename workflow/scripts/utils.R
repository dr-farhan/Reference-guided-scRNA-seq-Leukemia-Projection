# Shared input, metadata and plotting helpers.

message_time <- function(...) {
  message(format(Sys.time(), "[%Y-%m-%d %H:%M:%S] "), ...)
}

sanitize_name <- function(x) {
  x <- gsub("[^A-Za-z0-9._-]+", "_", x)
  gsub("^_+|_+$", "", x)
}

infer_treatment_group <- function(metadata) {
  n_cells <- nrow(metadata)
  get_text <- function(field) {
    if (field %in% colnames(metadata)) {
      tolower(trimws(as.character(metadata[[field]])))
    } else {
      rep("", n_cells)
    }
  }
  treatment_text <- get_text("treatment")
  timepoint_text <- get_text("timepoint")
  sample_text <- if (".analysis_sample" %in% colnames(metadata)) {
    tolower(trimws(as.character(metadata$.analysis_sample)))
  } else {
    get_text("sample_id")
  }
  combined_text <- paste(treatment_text, timepoint_text, sample_text)
  answer <- rep("Other", n_cells)
  answer[grepl("azacitidine|(^|[^a-z])aza([^a-z]|$)", combined_text)] <- "AZA"
  answer[grepl("decitabine|(^|[^a-z])dac([^a-z]|$)|eoln", combined_text)] <- "DAC"
  control <- grepl(
    "dmso|control|vehicle|untreated|screening|baseline|(^| )none( |$)",
    combined_text
  )
  answer[answer == "Other" & control] <- "Control"
  answer
}

ordered_cluster_ids <- function(x) {
  ids <- unique(as.character(x))
  numeric_ids <- suppressWarnings(as.numeric(ids))
  if (all(is.finite(numeric_ids))) ids[order(numeric_ids)] else sort(ids)
}

save_plot <- function(plot, stem, width, height) {
  pdf_path <- file.path(figure_dir, paste0(stem, ".pdf"))
  png_path <- file.path(figure_dir, paste0(stem, ".png"))
  ggsave(pdf_path, plot = plot, width = width, height = height,
         units = "in", device = cairo_pdf, bg = "white", limitsize = FALSE)
  ggsave(png_path, plot = plot, width = width, height = height,
         units = "in", dpi = 400, bg = "white", limitsize = FALSE)
  invisible(c(pdf = pdf_path, png = png_path))
}

theme_publication <- function(base_size = 10) {
  theme_classic(base_size = base_size) +
    theme(
      axis.title = element_text(face = "bold"),
      plot.title = element_text(face = "bold", hjust = 0),
      plot.subtitle = element_text(color = "grey30"),
      legend.title = element_text(face = "bold"),
      strip.background = element_rect(fill = "grey95", color = "grey70"),
      strip.text = element_text(face = "bold")
    )
}

resolve_input_files <- function(paths, pattern, recursive = TRUE) {
  files <- unlist(lapply(paths, function(path) {
    path <- path.expand(trimws(path))
    if (dir.exists(path)) {
      list.files(path, pattern = pattern, recursive = recursive,
                 full.names = TRUE, ignore.case = TRUE)
    } else if (file.exists(path)) {
      path
    } else {
      character(0)
    }
  }), use.names = FALSE)
  unique(normalizePath(files, mustWork = TRUE))
}

get_counts <- function(object, assay = "RNA") {
  if (packageVersion("Seurat") >= numeric_version("5.0.0")) {
    Seurat::GetAssayData(object, assay = assay, layer = "counts")
  } else {
    Seurat::GetAssayData(object, assay = assay, slot = "counts")
  }
}

join_rna_layers_if_needed <- function(object) {
  if (packageVersion("Seurat") >= numeric_version("5.0.0")) {
    layer_names <- SeuratObject::Layers(object[["RNA"]])
    count_layers <- grep("^counts", layer_names, value = TRUE)
    if (length(count_layers) > 1L) {
      object <- SeuratObject::JoinLayers(object, assay = "RNA")
    }
  }
  object
}

dominant_value <- function(x, fallback = "Unresolved") {
  x <- x[!is.na(x) & nzchar(x)]
  if (!length(x)) return(fallback)
  tab <- sort(table(x), decreasing = TRUE)
  names(tab)[1]
}

pretty_label <- function(x) {
  x <- gsub("_", " ", as.character(x))
  x <- gsub("\\s+", " ", x)
  trimws(x)
}

manual_palette <- function(categories) {
  categories <- sort(unique(categories[!is.na(categories)]))
  base <- c(
    "Low-confidence / unmapped" = "#BDBDBD",
    "Unresolved" = "#969696"
  )
  remaining <- setdiff(categories, names(base))
  if (length(remaining)) {
    cols <- scales::hue_pal(l = 60, c = 100)(length(remaining))
    base <- c(base, stats::setNames(cols, remaining))
  }
  base[categories]
}

