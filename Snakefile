from pathlib import Path
import json
import re
import sys
from snakemake.utils import validate

configfile: "config/config.yaml"

validate(config, "workflow/config.schema.yaml")
OUT = config["output_dir"].rstrip("/")
REF = config["reference_cache_dir"].rstrip("/")
RSCRIPT = config["rscript"]
SCRIPTS = "workflow/scripts"
COMMON_CODE = [f"{SCRIPTS}/{name}" for name in
               ("run_stage.R", "bootstrap.R", "packages.R", "utils.R")]
STAGE_CODE = {
    "prepare": COMMON_CODE + [f"{SCRIPTS}/01_prepare_input.R"],
    "project": COMMON_CODE + [f"{SCRIPTS}/02_project_reference.R",
                              f"{SCRIPTS}/03_annotate_lineages.R"],
    "native": COMMON_CODE + [f"{SCRIPTS}/04_native_embedding.R"],
    "report": COMMON_CODE + sorted(str(p) for p in Path(SCRIPTS).glob("*.R")
                                   if re.match(r"(0[5-9]|1[0-2])_", p.name)),
    "export": COMMON_CODE + [f"{SCRIPTS}/13_export_object.R"],
}

# Expand directories at DAG construction so changes to input files are tracked.
INPUTS = []
for entry in config["input_paths"]:
    path = Path(entry).expanduser()
    if path.is_dir():
        candidates = path.rglob("*") if config["search_input_recursively"] else path.glob("*")
        INPUTS.extend(str(p) for p in sorted(candidates)
                      if p.is_file() and re.search(config["input_pattern"], p.name, re.I))
    else:
        INPUTS.append(str(path))
INPUTS = list(dict.fromkeys(INPUTS))
if not INPUTS:
    raise WorkflowError("No input RDS files matched input_paths/input_pattern")
config["input_paths"] = INPUTS

rule all:
    input:
        lambda wildcards: rules.figures_and_tables.output,
        lambda wildcards: rules.export_object.output,

# Explicit, always-run check; no checkpoint reads or reference downloads.
rule preflight:
    params:
        python=sys.executable,
        resolved=json.dumps(config, sort_keys=True),
    shell:
        "{params.python:q} {SCRIPTS}/preflight.py --config-json {params.resolved:q}"

rule resolve_config:
    output:
        f"{OUT}/provenance/config.yaml",
    params:
        resolved=json.dumps(config, sort_keys=True),
    log:
        f"{OUT}/logs/resolve_config.log",
    run:
        import yaml
        Path(output[0]).parent.mkdir(parents=True, exist_ok=True)
        with open(output[0], "w") as handle:
            yaml.safe_dump(json.loads(params.resolved), handle, sort_keys=False)
        Path(log[0]).write_text("Saved resolved configuration.\n")

rule download_reference:
    output:
        reference=f"{REF}/BoneMarrowMap_SymphonyReference.rds",
        model=f"{REF}/BoneMarrowMap_uwot_model.uwot",
    log:
        f"{OUT}/logs/download_reference.log",
    params:
        script="workflow/scripts/download_reference.py",
        python=sys.executable,
    shell:
        "{params.python:q} {params.script:q} {output.reference:q} {output.model:q} > {log:q} 2>&1"

rule prepare_input:
    input:
        config=rules.resolve_config.output,
        data=INPUTS,
        code=STAGE_CODE["prepare"],
    output:
        state=temp(f"{OUT}/checkpoints/01_input.rds"),
        qc=f"{OUT}/tables/00_input_metadata.csv.gz",
    threads: config["threads"]
    resources:
        mem_mb=config["mem_mb"],
    log:
        f"{OUT}/logs/01_prepare_input.log",
    benchmark:
        f"{OUT}/benchmarks/01_prepare_input.tsv"
    shell:
        "OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 "
        "RCPP_PARALLEL_NUM_THREADS={threads} {RSCRIPT:q} --vanilla "
        "{SCRIPTS}/run_stage.R prepare {input.config:q} - {output.state:q} {SCRIPTS:q} "
        "> {log:q} 2>&1"

rule project_reference:
    input:
        config=rules.resolve_config.output,
        state=rules.prepare_input.output.state,
        reference=rules.download_reference.output,
        code=STAGE_CODE["project"],
    output:
        state=temp(f"{OUT}/checkpoints/02_projected.rds"),
    threads: config["threads"]
    resources:
        mem_mb=config["mem_mb"],
    log:
        f"{OUT}/logs/02_project_reference.log",
    benchmark:
        f"{OUT}/benchmarks/02_project_reference.tsv"
    shell:
        "OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 "
        "RCPP_PARALLEL_NUM_THREADS={threads} {RSCRIPT:q} --vanilla "
        "{SCRIPTS}/run_stage.R project {input.config:q} {input.state:q} {output.state:q} {SCRIPTS:q} "
        "> {log:q} 2>&1"

rule native_embedding:
    input:
        config=rules.resolve_config.output,
        state=rules.project_reference.output.state,
        code=STAGE_CODE["native"],
    output:
        state=f"{OUT}/checkpoints/03_native.rds",
    threads: config["threads"]
    resources:
        mem_mb=config["mem_mb"],
    log:
        f"{OUT}/logs/03_native_embedding.log",
    benchmark:
        f"{OUT}/benchmarks/03_native_embedding.tsv"
    shell:
        "OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 "
        "RCPP_PARALLEL_NUM_THREADS={threads} {RSCRIPT:q} --vanilla "
        "{SCRIPTS}/run_stage.R native {input.config:q} {input.state:q} {output.state:q} {SCRIPTS:q} "
        "> {log:q} 2>&1"

rule figures_and_tables:
    input:
        config=rules.resolve_config.output,
        state=rules.native_embedding.output.state,
        reference=rules.download_reference.output,
        code=STAGE_CODE["report"],
    output:
        manifest=f"{OUT}/provenance/figure_manifest.csv",
        figures=directory(f"{OUT}/figures"),
        cells=f"{OUT}/tables/cell_annotations.csv.gz",
        clusters=f"{OUT}/tables/cluster_summary.csv",
        composition=f"{OUT}/tables/cell_state_composition.csv",
        lineage=f"{OUT}/tables/cluster_by_reference_lineage_proportions.csv",
        methods=f"{OUT}/METHODS_AND_INTERPRETATION.txt",
        session=f"{OUT}/sessionInfo.txt",
    threads: config["threads"]
    resources:
        mem_mb=config["mem_mb"],
    log:
        f"{OUT}/logs/04_figures_and_tables.log",
    benchmark:
        f"{OUT}/benchmarks/04_figures_and_tables.tsv"
    shell:
        "OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 "
        "RCPP_PARALLEL_NUM_THREADS={threads} {RSCRIPT:q} --vanilla "
        "{SCRIPTS}/run_stage.R report {input.config:q} {input.state:q} {output.manifest:q} {SCRIPTS:q} "
        "> {log:q} 2>&1"

rule export_object:
    input:
        config=rules.resolve_config.output,
        state=rules.native_embedding.output.state,
        code=STAGE_CODE["export"],
    output:
        object=f"{OUT}/objects/AML_BoneMarrowMap_annotated.seurat.rds",
    threads: config["threads"]
    resources:
        mem_mb=config["mem_mb"],
    log:
        f"{OUT}/logs/05_export_object.log",
    benchmark:
        f"{OUT}/benchmarks/05_export_object.tsv"
    shell:
        "OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 "
        "RCPP_PARALLEL_NUM_THREADS={threads} {RSCRIPT:q} --vanilla "
        "{SCRIPTS}/run_stage.R export {input.config:q} {input.state:q} {output.object:q} {SCRIPTS:q} "
        "> {log:q} 2>&1"
