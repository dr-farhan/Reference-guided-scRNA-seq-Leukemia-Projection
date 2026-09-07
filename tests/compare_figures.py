"""Compare retained V2 PNGs; require byte identity for unchanged figure groups."""
import csv
from pathlib import Path
import sys

old, new, destination = map(Path, sys.argv[1:])
rows = []
for path in sorted((new / 'figures').glob('*.png')):
    original = old / 'figures' / path.name
    unchanged = path.name.startswith(('01_', '02_', '04_', '06_', '13_'))
    rows.append(dict(figure=path.name, unchanged_analysis=unchanged,
                     original_exists=original.exists(),
                     byte_identical=original.exists() and path.read_bytes() == original.read_bytes()))
assert rows, 'No figures to compare'
destination.parent.mkdir(parents=True, exist_ok=True)
with destination.open('w') as handle:
    writer = csv.DictWriter(handle, fieldnames=rows[0], lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
unchanged = [row for row in rows if row['unchanged_analysis']]
assert all(row['byte_identical'] for row in unchanged), 'An unchanged figure differs'
print(f'PASS: {len(unchanged)} unchanged PNGs are byte-identical to V2.')
