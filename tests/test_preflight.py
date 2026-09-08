"""Exercise preflight diagnostics without requiring an R installation."""
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("preflight", ROOT / "workflow/scripts/preflight.py")
preflight = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preflight)


class PreflightChecks(unittest.TestCase):
    def test_missing_paths_are_reported_together(self):
        with tempfile.TemporaryDirectory() as directory:
            config = {"rscript": directory + "/missing/Rscript",
                      "input_paths": [directory + "/missing.rds"],
                      "reference_cache_dir": directory}
            errors = preflight.check(config)
        self.assertEqual(len(errors), 4)
        self.assertIn(config["rscript"], errors[0])
        self.assertIn("Input RDS", errors[1])
        self.assertTrue(all("Reference file" in error for error in errors[2:]))

    def test_package_failure_and_success(self):
        with tempfile.TemporaryDirectory(prefix="projection check ") as directory:
            for name in ("query.rds", "BoneMarrowMap_SymphonyReference.rds",
                         "BoneMarrowMap_uwot_model.uwot"):
                Path(directory, name).touch()
            config = {"rscript": "/configured R/bin/Rscript",
                      "input_paths": [directory + "/query.rds"],
                      "reference_cache_dir": directory}
            with patch.object(preflight.shutil, "which", return_value=config["rscript"]), \
                 patch.object(preflight.subprocess, "run") as run:
                run.return_value = subprocess.CompletedProcess([], 1, "", "symphony: load failed")
                errors = preflight.check(config)
                self.assertEqual(len(errors), 1)
                self.assertIn("symphony: load failed", errors[0])
                self.assertEqual(run.call_args.args[0][0], config["rscript"])
                self.assertEqual(run.call_args.args[0][1], "--vanilla")
                lock = json.loads((ROOT / "renv.lock").read_text())
                self.assertEqual(run.call_args.args[0][-2:], [
                    lock["Packages"][name]["Version"] for name in ("Seurat", "SeuratObject")])
                run.return_value = subprocess.CompletedProcess([], 0, "", "")
                self.assertEqual(preflight.check(config), [])
                run.side_effect = OSError("exec format error")
                self.assertIn("Cannot execute Rscript", preflight.check(config)[0])


@unittest.skipUnless(shutil.which("Rscript"), "Rscript is not on PATH")
class RPackageCompatibility(unittest.TestCase):
    def run_check(self, seurat, seurat_object, missing=""):
        # Execute the actual preflight R code with package lookups stubbed, so
        # incompatible combinations can be tested without installing them.
        stubs = '''
packageVersion <- function(package) {
  package_version(commandArgs(trailingOnly = TRUE)[if (package == "Seurat") 4 else 5])
}
library <- function(package, ...) {
  cat("Checked:", package, "\\n")
  if (package %in% strsplit(commandArgs(trailingOnly = TRUE)[6], ",")[[1]]) {
    stop("package unavailable")
  }
}
'''
        lock = json.loads((ROOT / "renv.lock").read_text())
        recommended = [lock["Packages"][name]["Version"]
                       for name in ("Seurat", "SeuratObject")]
        return subprocess.run(
            [shutil.which("Rscript"), "--vanilla", "-e", stubs + preflight.PACKAGE_CHECK_R,
             str(ROOT / "workflow/scripts/packages.R"), *recommended,
             seurat, seurat_object, missing], capture_output=True, text=True)

    def test_recommended_pair_and_explicit_dependencies(self):
        lock = json.loads((ROOT / "renv.lock").read_text())
        result = self.run_check(*(lock["Packages"][name]["Version"]
                                  for name in ("Seurat", "SeuratObject")))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("Warning", result.stderr)
        for name in ("AUCell", "BiocNeighbors"):
            self.assertIn("Checked: " + name, result.stdout)

    def test_mixed_major_versions_fail_with_recommendation(self):
        for seurat, seurat_object in (("4.4.0", "5.4.0"), ("5.5.1", "4.1.4")):
            with self.subTest(seurat=seurat, seurat_object=seurat_object):
                result = self.run_check(seurat, seurat_object)
                self.assertNotEqual(result.returncode, 0)
                for text in (seurat, seurat_object, "Incompatible", "renv.lock", "INSTALL.md"):
                    self.assertIn(text, result.stderr)

    def test_projectdim_incompatible_versions_fail(self):
        result = self.run_check("5.1.0", "5.4.0")
        self.assertNotEqual(result.returncode, 0)
        for text in ("5.1.0", "5.4.0", "GetAssayData(slot=...)", "ProjectDim()",
                     "renv.lock", "5.5.1"):
            self.assertIn(text, result.stderr)

    def test_other_versions_warn_without_blanket_rejection(self):
        result = self.run_check("5.5.0", "5.4.0")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Tested/recommended renv.lock", result.stderr)

    def test_explicit_dependencies_fail_individually(self):
        result = self.run_check("5.5.1", "5.4.0", "AUCell,BiocNeighbors")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("AUCell: package unavailable", result.stderr)
        self.assertIn("BiocNeighbors: package unavailable", result.stderr)


if __name__ == "__main__":
    unittest.main()
