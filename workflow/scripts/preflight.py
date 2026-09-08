"""Check paths and R package loading without reading single-cell objects."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


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
        expression = '''
source(commandArgs(trailingOnly = TRUE)[1])
failed <- character()
for (package in required_packages) {
  tryCatch(suppressPackageStartupMessages(library(package, character.only = TRUE)),
    error = function(e) {
      failed <<- c(failed, paste0(package, ": ", conditionMessage(e)))
    })
}
if (length(failed)) stop("Required R packages failed to load:\\n", paste(failed, collapse = "\\n"))
'''
        try:
            result = subprocess.run(
                [rscript, "--vanilla", "-e", expression,
                 str(Path(__file__).with_name("packages.R").resolve())],
                capture_output=True, text=True, check=False)
            if result.returncode:
                errors.append(f"R package check failed using {rscript}:\n{result.stderr}{result.stdout}")
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
