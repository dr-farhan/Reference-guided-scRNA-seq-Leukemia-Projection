# Installation

The workflow uses a Python/Snakemake environment and an R environment. The full GSE145410 test uses the existing R installation from the original V2 launcher. A clean restoration of the R environment is a separate operation and is not implied by that validation.

## Snakemake

```bash
conda env create -f environment.yaml
conda activate leukemia-projection-workflow
snakemake --version
```

Alternatively, install `snakemake==9.16.3` in a Python 3.11 virtual environment. PyYAML and jsonschema are installed as Snakemake dependencies.

## R: use an existing analysis environment

The pipeline needs Seurat, SeuratObject, BoneMarrowMap, Symphony, and the plotting/data packages listed in `workflow/scripts/bootstrap.R`. BoneMarrowMap itself imports AUCell, although this workflow does not run its gene-set scoring functions.

Set `rscript` in `config/local.yaml` to the existing environment's `Rscript`. The validator's exact package versions are recorded in `renv.lock`; the source R environment inventory is in `validation/r_packages.csv`.

## R: restore a dedicated environment

The lockfile records R 4.4.3, package versions, repositories, and GitHub commit SHAs. Create a separate R environment so restoration does not alter another project's packages:

```bash
conda env create -f workflow/envs/r.yaml
conda activate leukemia-projection-r
Rscript --vanilla -e 'install.packages("renv", repos="https://cloud.r-project.org")'
Rscript --vanilla -e 'renv::restore(lockfile="renv.lock", library=.libPaths()[1], prompt=FALSE)'
```

Run restoration from the repository root. The explicit `library` argument installs into this dedicated R environment; the workflow runs `Rscript --vanilla` and does not depend on automatic `.Rprofile` activation. Point `config/local.yaml` to this environment's `Rscript`, then reactivate the Snakemake environment.

Source packages may require additional OS-specific development libraries. Availability of historical CRAN/Bioconductor packages and external references depends on their upstream hosts. The lockfile captures the tested environment; it is not a container image. See the [validation limitations](validation/README.md#scope-and-limitations) for a pre-existing optional dependency-version inconsistency in that environment.

## Reference assets

The workflow downloads these upstream assets when absent:

- `https://bonemarrowmap.s3.us-east-2.amazonaws.com/BoneMarrowMap_SymphonyReference.rds`
- `https://bonemarrowmap.s3.us-east-2.amazonaws.com/BoneMarrowMap_uwot_model.uwot`

For exact reproduction of the local validation, use the cached files identified by checksums in `validation/input_checksums.json`. The upstream URLs are not versioned, so future downloads are not guaranteed to match those files. The example GSE145410 configuration reuses the original V2 cache without downloading the unused differentiation GMT.

On systems with a read-only home cache, set `XDG_CACHE_HOME` to a writable directory before launching Snakemake.
