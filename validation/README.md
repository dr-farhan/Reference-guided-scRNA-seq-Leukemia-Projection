# GSE145410 validation

**Status: PASS.** Tested on 2026-09-07 with Snakemake 9.16.3 and R 4.4.3, using the original V2 R environment and cached reference assets.

| Check | Observed result |
| --- | --- |
| Full Snakemake execution from the original raw-count RDS | 7/7 scheduled jobs completed |
| Cells / biological samples | 19,471 / 4 |
| Mapping-usable cells | 17,005 |
| Native clusters | 13 |
| Figures | 23 PDF/PNG pairs (46 files) |
| Retained per-cell fields vs V2 | 36/36 identical |
| Largest absolute error across compared numeric fields | 0 |
| Lineage-only composition reconstructed from V2 | Exact match |
| Native cluster counts and mapping QC | Exact match |
| Unchanged PNG figures (01, 02, 04, 06, 13) | 11/11 byte-identical |
| Seurat assay matrices, variable genes, embeddings, PCA loadings and graphs | 17/17 identical |
| Excluded output annotations | Absent |
| Resume dry run | Nothing to be done |
| Python configuration/scope tests | 3 passed |
| R module parsing | All passed |

The full execution used `--cores 1` in an existing compute allocation. The four analysis stages took approximately 10.9 minutes in total. The largest sampled stage RSS was approximately 17.0 GiB. These measurements apply to this dataset and environment; they are not universal memory requirements.

## Evidence

- [Input and reference SHA-256 checksums](input_checksums.json)
- [Source script provenance](source_provenance.json)
- [Output integrity checks](output_checks.json)
- [Per-field V2 comparison](v2_comparison.csv)
- [Seurat object comparison](object_comparison.json)
- [Figure comparison](figure_comparison.csv)
- [Figure sizes and MD5 checksums](figure_manifest.csv)
- [Runtime and memory benchmarks](benchmarks.tsv)
- [Session information](sessionInfo.txt)
- [Source R environment package inventory](r_packages.csv)

## Reproduce the checks

From the repository root with the original dataset directory beside it:

```bash
snakemake --cores 1 --configfile config/gse145410.yaml config/local.yaml --rerun-incomplete
Rscript --vanilla tests/compare_v2.R \
  ../single_cell_dataset_GSE145410/Revised_V2 results/GSE145410 validation/local
python tests/compare_figures.py \
  ../single_cell_dataset_GSE145410/Revised_V2 results/GSE145410 validation/local/figure_comparison.csv
snakemake --cores 1 --configfile config/gse145410.yaml config/local.yaml --dry-run
```

For the R comparison, use the same Rscript configured for the workflow. The comparison reads the existing original V2 outputs; it does not rerun any removed analysis. The `.input_file` field is excluded from parity checks because it is execution provenance. `final_annotation` and `cluster_interpretation` are deliberately changed to lineages. All other 36 per-cell fields present in the new output are compared.

## Scope and limitations

This is a complete test on GSE145410, not a subsampled or synthetic analysis. GSE223844 has not been run through this workflow. The tests establish parity for the retained V2 behavior on this input; other datasets can require different input QC or interpretation.

The 12 changed/new PNGs are the lineage-only panels and standalone pseudotime panel described in the [crosswalk](../docs/analysis_crosswalk.md). Their differences are expected. Figures were checked for file integrity, and representative native-UMAP and lineage-heatmap panels were visually reviewed.

The recorded R environment was reused rather than restored from scratch. The lockfile preserves a pre-existing dependency-version inconsistency (`here` 1.0.2 requests `rprojroot` >= 2.1.0; the source environment has 2.0.4); neither package appears among the loaded namespaces in this validation. Clean environment restoration remains untested.

Snakemake lint reports environment-declaration and style recommendations: this workflow intentionally uses an explicitly configured external R environment, documented by its lockfile, rather than per-rule Conda restoration. Lint is not reported as passing. The structural CI uses empty path fixtures only for DAG construction and R syntax checks; it does not claim a biological-data integration test.
