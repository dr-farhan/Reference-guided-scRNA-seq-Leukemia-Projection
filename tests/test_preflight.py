"""Exercise preflight diagnostics without requiring an R installation."""
import importlib.util
from pathlib import Path
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
                run.return_value = subprocess.CompletedProcess([], 0, "", "")
                self.assertEqual(preflight.check(config), [])
                run.side_effect = OSError("exec format error")
                self.assertIn("Cannot execute Rscript", preflight.check(config)[0])


if __name__ == "__main__":
    unittest.main()
