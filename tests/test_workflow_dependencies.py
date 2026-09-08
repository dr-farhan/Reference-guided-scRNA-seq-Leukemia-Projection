"""Check rerun boundaries with placeholder outputs, never running analysis."""
from pathlib import Path
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which("snakemake"), "Snakemake is not on PATH")
class WorkflowDependencies(unittest.TestCase):
    def test_plot_edit_only_reruns_report(self):
        with tempfile.TemporaryDirectory(prefix="projection-dag-") as directory:
            root = Path(directory)
            shutil.copy2(ROOT / "Snakefile", root / "Snakefile")
            for name in ("workflow", "config"):
                shutil.copytree(ROOT / name, root / name)
            data = root / "data/query.raw.seurat.rds"
            data.parent.mkdir()
            data.touch()
            reference = root / "resources/reference"
            reference.mkdir(parents=True)
            for name in ("BoneMarrowMap_SymphonyReference.rds", "BoneMarrowMap_uwot_model.uwot"):
                (reference / name).touch()
            command = [sys.executable, "-m", "snakemake", "--cores", "1", "--quiet"]
            summary = subprocess.run(command[:-1] + ["--summary"], cwd=root,
                                     capture_output=True, text=True)
            self.assertEqual(summary.returncode, 0, summary.stdout + summary.stderr)
            # --touch records completion but does not create missing outputs.
            for line in summary.stdout.splitlines():
                columns = line.split("\t")
                if len(columns) < 5 or columns[0] == "output_file":
                    continue
                output = root / columns[0]
                if output == root / "results/figures":
                    output.mkdir(parents=True, exist_ok=True)
                else:
                    output.parent.mkdir(parents=True, exist_ok=True)
                    output.touch()
            completed = subprocess.run(command + ["--touch", "--forceall", "--notemp"], cwd=root,
                                       capture_output=True, text=True)
            self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
            object_path = root / "results/objects/AML_BoneMarrowMap_annotated.seurat.rds"
            self.assertTrue(object_path.exists())
            before = object_path.stat().st_mtime_ns
            plot = root / "workflow/scripts/06_plot_projection.R"
            plot.write_text(plot.read_text() + "\n# Plot-only change for dependency test.\n")
            # Ensure the changed input is newer even on coarse timestamp filesystems.
            future = max(p.stat().st_mtime for p in (root / "results").rglob("*") if p.is_file()) + 2
            os.utime(plot, (future, future))
            dry_run = subprocess.run(command[:-1] + ["--dry-run", "--nocolor"], cwd=root,
                                     capture_output=True, text=True)
            output = dry_run.stdout + dry_run.stderr
            self.assertEqual(dry_run.returncode, 0, output)
            self.assertIn("rule figures_and_tables:", output)
            for rule in ("prepare_input", "project_reference", "native_embedding", "export_object"):
                self.assertNotIn(f"rule {rule}:", output)
            self.assertEqual(object_path.stat().st_mtime_ns, before)


if __name__ == "__main__":
    unittest.main()
