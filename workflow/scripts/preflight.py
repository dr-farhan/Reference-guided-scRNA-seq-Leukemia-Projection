"""Check paths and R package loading without reading single-cell objects."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


PACKAGE_CHECK_R = '''
args <- commandArgs(trailingOnly = TRUE)
source(args[1])
# Explicit preflight checks for dependencies used by BoneMarrowMap.
required_packages <- unique(c(required_packages, "AUCell", "BiocNeighbors"))
failed <- character()
recommended <- paste0("Tested/recommended renv.lock environment: Seurat ", args[2],
                      " with SeuratObject ", args[3],
                      ". Restore renv.lock in a dedicated R environment (see INSTALL.md).")
tryCatch({
  seurat <- packageVersion("Seurat")
  object <- packageVersion("SeuratObject")
  installed <- paste0("Installed Seurat ", seurat, " with SeuratObject ", object, ". ")
  if ((seurat < "5.0.0" && object >= "5.0.0") ||
      (seurat >= "5.0.0" && object < "5.0.0")) {
    stop(installed, "Incompatible Seurat/SeuratObject major versions; ",
         "this can fail in BoneMarrowMap::map_Query(). ", recommended)
  }
  if (seurat < "5.3.1" && object > "5.2.0") {
    stop(installed, "Incompatible Seurat/SeuratObject versions: Seurat < 5.3.1 with ",
         "SeuratObject > 5.2.0 can trigger the defunct GetAssayData(slot=...) ",
         "error in ProjectDim(). ", recommended)
  }
  if (seurat != args[2] || object != args[3]) {
    warning(installed, recommended, call. = FALSE, immediate. = TRUE)
  }
}, error = function(e) {
  failed <<- c(failed, paste0("Seurat compatibility check: ", conditionMessage(e)))
})
for (package in required_packages) {
  tryCatch(suppressPackageStartupMessages(library(package, character.only = TRUE)),
    error = function(e) {
      failed <<- c(failed, paste0(package, ": ", conditionMessage(e)))
    })
}
if (length(failed)) stop("R preflight checks failed:\\n", paste(failed, collapse = "\\n"))
'''


def check(config):
    errors = []
    configured = os.path.expanduser(config["rscript"])
    rscript = shutil.which(configured)
    if not rscript:
        errors.append(f"Rscript does not exist or is not executable: {configured}")
    paths = [("Input RDS", Path(p).expanduser()) for p in config["input_paths"]]
    reference = Path(config["reference_cache_dir"])
    paths += [("Reference file", reference / name) for name in (
        "BoneMarrowMap_SymphonyReference.rds", "BoneMarrowMap_uwot_model.uwot")]
    for label, path in paths:
        if not path.is_file() or not os.access(path, os.R_OK):
            errors.append(f"{label} is missing or unreadable: {path}")
    if not config["input_paths"]:
        errors.append("No input RDS files configured")
    if rscript:
        try:
            script_dir = Path(__file__).resolve().parent
            lock = json.loads((script_dir.parents[1] / "renv.lock").read_text())
            recommended = [lock["Packages"][name]["Version"]
                           for name in ("Seurat", "SeuratObject")]
        except (OSError, ValueError, KeyError) as error:
            errors.append(f"Cannot read tested Seurat versions from renv.lock: {error}")
            return errors
        try:
            result = subprocess.run(
                [rscript, "--vanilla", "-e", PACKAGE_CHECK_R,
                 str(script_dir / "packages.R"), *recommended],
                capture_output=True, text=True, check=False)
            if result.returncode:
                errors.append(f"R package check failed using {rscript}:\n{result.stderr}{result.stdout}")
            elif result.stderr:
                # Keep recommendations visible even when all package checks pass.
                print(result.stderr, file=sys.stderr, end="")
        except OSError as error:
            errors.append(f"Cannot execute Rscript {rscript}: {error}")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config-json", required=True)
    args = parser.parse_args()
    errors = check(json.loads(args.config_json))
    if errors:
        print("Preflight failed:\n- " + "\n- ".join(errors), file=sys.stderr)
        return 1
    print("Preflight passed: Rscript, required R packages, input RDS and reference files are available.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
