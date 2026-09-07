# V2 analysis and figure crosswalk

The supplied GSE145410 and GSE223844 V2 R scripts differ only in candidate-state thresholds and the eligible primitive-label regex. Those differences are outside this workflow. Both retained analysis paths therefore use the same defaults.

| Original section | New section | Treatment |
| --- | --- | --- |
| Configuration and dependency setup | YAML, `bootstrap.R` | Portable paths; explicit environment setup |
| Input loading, merging, optional QC | `01_prepare_input.R` | Same filename prefixes, sample fallback and QC defaults |
| BoneMarrowMap mapping and label transfer | `02_project_reference.R` | Same functions and arguments |
| Mapping usability and major lineages | `03_annotate_lineages.R` | Same confidence logic; final annotation equals major lineage |
| Native UMAP and clustering | `04_native_embedding.R` | Same SCTransform, fallback, PCA, UMAP, graph and clustering settings |
| Cluster summaries | `04_native_embedding.R` | Retain counts, mapping usability, dominant lineage; remove candidate-state fractions and overrides |
| AUCell/GMT scoring and candidate classification | — | Removed entirely |
| LSC/BLAST pseudobulk launcher and analysis | — | Removed entirely |
| Final tables and Seurat export | `12_export_results.R` | Retained fields and embeddings; no candidate-state fields |

## Figures

| V2 number / output | Module | Result |
| --- | --- | --- |
| 01 Reference atlas | `05_plot_reference_qc.R` | Retained |
| 02 Mapping QC | `05_plot_reference_qc.R` | Retained |
| 03 Projected final annotations | `06_plot_projection.R` | Lineages only |
| 04 Projected broad and fine types | `06_plot_projection.R` | Retained |
| 05 Pseudotime and LSC scores | `06_plot_projection.R` | Pseudotime panel retained; score panels removed; standalone 7 × 6.5 inch figure |
| 06 Merged and per-sample projected density | `07_plot_density.R` | Retained |
| 07 Combined and treatment-specific native overviews | `08_plot_native.R` | Clusters and lineages retained; cluster interpretation becomes dominant lineage |
| 08 Native final annotations | `08_plot_native.R` | Lineages only |
| 09 Candidate-state highlights | — | Removed |
| 10 Signature means and per-sample score violins | — | Removed |
| 11 Marker dot plot | `09_plot_markers_composition.R` | Same marker genes; grouped by lineages only |
| 11 Focused candidate-state marker comparison | — | Removed |
| 12 Composition | `09_plot_markers_composition.R` | Same calculation; lineages only |
| 13 Combined and treatment-specific lineage heatmaps | `10_plot_concordance.R` | Retained |
| Per-sample native annotation panels | `11_plot_samples.R` | Lineages only |

The remaining marker panel includes stem/progenitor markers as part of hematopoietic lineage validation. Their presence does not create a candidate-state classification. Reference labels such as HSC/MPP are likewise retained as normal hematopoietic annotations.

## Numerical and rendering parity

The retained mapping and native analysis operations are preserved. Removing scoring eliminates random-number draws and metadata fields, so equivalence must be measured rather than assumed. `tests/compare_v2.R` compares all retained per-cell columns, including both embeddings, with numeric tolerance `1e-8`, and reconstructs lineage-only composition from the original results. It also checks native cluster counts and mapping-QC summaries.

Lineage-only panels intentionally change group labels, color palettes, group-level expression summaries and composition fractions relative to plots containing candidate-state overrides. PDF creation metadata and repelled label positions can differ between runs. Byte identity of every original figure is therefore not the acceptance criterion. The validation report records the observed numerical and image comparisons separately.

## Operational differences

- Four explicit R processes replace one monolithic process. Intermediate state includes the R random-number state.
- Input and projected checkpoints are temporary; the native checkpoint is retained for report regeneration.
- Missing packages cause a clear failure; analysis rules never install packages implicitly.
- The workflow can download reference assets, or reuse the V2 cache. The AML differentiation GMT is not needed.
- Raw datasets, reference files, full results and machine-specific configurations remain outside Git.
