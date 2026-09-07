"""Fail the workflow if retained outputs are incomplete or inconsistent."""
import csv
import gzip
import hashlib
import json
from pathlib import Path
import re
import sys

root, destination = map(Path, sys.argv[1:])
with gzip.open(root / "tables/cell_annotations.csv.gz", "rt") as handle:
    reader = csv.DictReader(handle)
    columns = reader.fieldnames
    cells = list(reader)
assert cells, "No annotated cells"
assert len({row["cell"] for row in cells}) == len(cells), "Duplicate cell IDs"
for column in columns:
    assert not re.search(r"lsc|blast|lspc|malignancy_gate|primitive_mapped|kmt2a|_AUC$", column, re.I), column
assert all(row["major_lineage"] == row["final_annotation"] for row in cells)
with (root / "tables/cell_state_composition.csv").open() as handle:
    composition = list(csv.DictReader(handle))
assert sum(int(row["n_cells"]) for row in composition) == len(cells)
with (root / "tables/cluster_summary.csv").open() as handle:
    clusters = list(csv.DictReader(handle))
assert sum(int(row["n_cells"]) for row in clusters) == len(cells)
with (root / "provenance/figure_manifest.csv").open() as handle:
    figures = list(csv.DictReader(handle))
assert figures, "No figures"
for entry in figures:
    path = root / "figures" / entry["file"]
    assert not re.search(r"lsc|blast", path.name, re.I), path
    assert path.stat().st_size == int(entry["bytes"]) > 1000, path
    assert hashlib.md5(path.read_bytes()).hexdigest() == entry["md5"], path
    magic = path.read_bytes()[:8]
    assert magic.startswith(b"%PDF") if path.suffix == ".pdf" else magic == b"\x89PNG\r\n\x1a\n", path
stems = {Path(entry["file"]).stem for entry in figures}
for prefix in ("01_", "02_", "03_", "04_", "05_", "06_", "07_", "08_", "11_", "12_", "13_"):
    assert any(stem.startswith(prefix) for stem in stems), prefix
for stem in stems:
    assert {Path(entry["file"]).suffix for entry in figures if Path(entry["file"]).stem == stem} == {".pdf", ".png"}, stem
report = dict(status="PASS", cells=len(cells), samples=len({r[".analysis_sample"] for r in cells}),
              clusters=len({r["patient_cluster"] for r in cells}), figures=len(figures),
              figure_pairs=len(stems), excluded_annotations_absent=True)
destination.parent.mkdir(parents=True, exist_ok=True)
destination.write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))
