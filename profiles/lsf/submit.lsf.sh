#!/usr/bin/env bash
#BSUB -J reference_projection
#BSUB -q standard
#BSUB -n 4
#BSUB -R "rusage[mem=24000] span[hosts=1]"
#BSUB -M 24000
#BSUB -W 24:00
#BSUB -o lsf_projection.%J.out
#BSUB -e lsf_projection.%J.err
set -euo pipefail
# Submit from the repository root after activating your workflow environment.
snakemake --profile profiles/local --configfile config/config.yaml config/local.yaml
