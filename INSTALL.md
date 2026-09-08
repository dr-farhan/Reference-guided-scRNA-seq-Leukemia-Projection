# Installation

The workflow uses a Python/Snakemake environment and an R environment. Choose an existing R environment or restore the package versions recorded in `renv.lock`.

## Snakemake

```bash
conda env create -f environment.yaml
conda activate leukemia-projection-workflow
snakemake --version
```

Alternatively, install `snakemake==9.16.3` in a Python 3.11 virtual environment. PyYAML and jsonschema are installed as Snakemake dependencies.

## R: use an existing analysis environment

The pipeline needs Seurat, SeuratObject, BoneMarrowMap, Symphony, and the plotting/data packages listed in `workflow/scripts/bootstrap.R`. BoneMarrowMap itself imports AUCell, although this workflow does not run its gene-set scoring functions.

Set `rscript` in `config/local.yaml` to the existing environment's `Rscript`. Package versions and source repositories are recorded in `renv.lock`.

## R: restore a dedicated environment

The lockfile records R 4.4.3, package versions, repositories, and GitHub commit SHAs. Create a separate R environment so restoration does not alter another project's packages:

```bash
conda env create -f workflow/envs/r.yaml
conda activate leukemia-projection-r
Rscript --vanilla -e 'install.packages("renv", repos="https://cloud.r-project.org")'
Rscript --vanilla -e 'renv::restore(lockfile="renv.lock", library=.libPaths()[1], prompt=FALSE)'
```

Run restoration from the repository root. The explicit `library` argument installs into this dedicated R environment; the workflow runs `Rscript --vanilla` and does not depend on automatic `.Rprofile` activation. Point `config/local.yaml` to this environment's `Rscript`, then reactivate the Snakemake environment.

Source packages may require additional OS-specific development libraries. Availability of historical CRAN/Bioconductor packages and external references depends on their upstream hosts. The lockfile records the source environment; clean restoration has not been tested. It includes a pre-existing dependency mismatch: `here` 1.0.2 requests `rprojroot` >= 2.1.0, while the recorded version is 2.0.4.

## Reference assets

The workflow downloads these upstream assets when absent:

- `https://bonemarrowmap.s3.us-east-2.amazonaws.com/BoneMarrowMap_SymphonyReference.rds`
- `https://bonemarrowmap.s3.us-east-2.amazonaws.com/BoneMarrowMap_uwot_model.uwot`

The upstream URLs are not versioned. For reproducible analyses, retain the reference files you use and record their checksums. Set `reference_cache_dir` to reuse a local cache.

On systems with a read-only home cache, set `XDG_CACHE_HOME` to a writable directory before launching Snakemake.
